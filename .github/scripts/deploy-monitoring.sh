
#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# DataOps Monitoring Configuration Deployment
# ============================================================

PROJECT_DIR="/opt/dataops/app/aws-dataops-observability-pipeline"
REPO="MohammedZayed1/aws-dataops-observability-pipeline"
EC2_NETWORK="aws-dataops-observability-pipeline_default"

COMMIT="${1:?Usage: deploy-monitoring.sh <github-commit-sha>}"

if ! [[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERROR: Invalid Git commit SHA."
    exit 1
fi

BASE_URL="https://raw.githubusercontent.com/$REPO/$COMMIT"

TEMP_DIR=$(mktemp -d /tmp/dataops-monitoring-XXXXXX)

BACKUP_DIR=""
BACKUP_READY=0
INSTALL_STARTED=0
ROLLBACK_SUCCEEDED=0


declare -a SERVICES_TO_RESTART=()

service_is_selected() {
    local requested="$1"
    local service

    for service in "${SERVICES_TO_RESTART[@]}"; do
        if [[ "$service" == "$requested" ]]; then
            return 0
        fi
    done

    return 1
}

# ============================================================
# Health verification functions
# ============================================================

wait_for_prometheus() {
    local attempt=0

    until curl -fsS http://localhost:9090/-/ready >/dev/null; do
        attempt=$((attempt + 1))

        if [ "$attempt" -ge 30 ]; then
            echo "ERROR: Prometheus did not become ready."
            return 1
        fi

        sleep 5
    done

    echo "Prometheus is ready."
}

wait_for_alertmanager() {
    local attempt=0

    until docker run --rm \
        --network "$EC2_NETWORK" \
        curlimages/curl:8.12.1 \
        -fsS http://alertmanager:9093/-/ready >/dev/null 2>&1; do

        attempt=$((attempt + 1))

        if [ "$attempt" -ge 30 ]; then
            echo "ERROR: Alertmanager did not become ready."
            return 1
        fi

        sleep 5
    done

    echo "Alertmanager is ready."
}

verify_restarted_services() {
    echo "Checking restarted service containers..."

    for service in "${SERVICES_TO_RESTART[@]}"; do
        local attempt=0
        local container_id=""

        until container_id=$(docker compose ps --status running -q "$service") &&
              [ -n "$container_id" ]; do
            attempt=$((attempt + 1))

            if [ "$attempt" -ge 30 ]; then
                echo "ERROR: Service $service did not reach running state."
                return 1
            fi

            sleep 5
        done

        echo "Service $service is running."

        if [ "$service" = "grafana" ]; then
            attempt=0

            until curl -fsS http://localhost:3000/api/health >/dev/null; do
                attempt=$((attempt + 1))

                if [ "$attempt" -ge 30 ]; then
                    echo "ERROR: Grafana health endpoint is not responding."
                    return 1
                fi

                sleep 5
            done

            echo "Grafana health endpoint is responding."
        fi
    done
}

verify_monitoring() {
    local attempt=0
    local max_attempts=12

    echo "Checking Prometheus and Alertmanager..."

    while true; do
        attempt=$((attempt + 1))
        echo "Monitoring verification attempt $attempt/$max_attempts"

        if python3 - <<'PYTHON_EOF'
import json
import sys
import urllib.request

def get_json(url):
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)

# Verify every expected Prometheus scrape target.
targets = get_json("http://localhost:9090/api/v1/targets")
active_targets = targets["data"]["activeTargets"]

required_jobs = {
    "prometheus",
    "node-exporter",
    "nginx-exporter"
}

targets_by_job = {
    job: [
        target for target in active_targets
        if target["labels"].get("job") == job
    ]
    for job in required_jobs
}

failed_jobs = []

for job, job_targets in targets_by_job.items():
    if not job_targets:
        failed_jobs.append(f"{job}: no active targets")
        continue

    unhealthy = [
        target for target in job_targets
        if target["health"] != "up"
    ]

    if unhealthy:
        failed_jobs.append(
            f"{job}: {len(unhealthy)} unhealthy target(s)"
        )

if failed_jobs:
    print("ERROR: Prometheus target verification failed:")
    for failure in failed_jobs:
        print(" -", failure)
    sys.exit(1)

print("All expected Prometheus targets are UP.")

# Verify all expected alert rules.
rules = get_json("http://localhost:9090/api/v1/rules")

all_rules = [
    rule
    for group in rules["data"]["groups"]
    for rule in group["rules"]
]

expected_rules = {
    "HighCPUUsage",
    "HighMemoryUsage",
    "LowDiskSpace",
    "MonitoringTargetDown"
}

healthy_rules = {
    rule["name"]
    for rule in all_rules
    if rule["health"] == "ok"
}

missing_rules = expected_rules - healthy_rules

if missing_rules:
    print("ERROR: Missing or unhealthy alert rules:", sorted(missing_rules))
    sys.exit(1)

print("All four Prometheus alert rules are loaded and healthy.")

# Verify Prometheus has discovered Alertmanager.
alertmanagers = get_json(
    "http://localhost:9090/api/v1/alertmanagers"
)

active_alertmanagers = alertmanagers["data"]["activeAlertmanagers"]

if not active_alertmanagers:
    print("ERROR: Prometheus cannot discover Alertmanager.")
    sys.exit(1)

print("Prometheus successfully discovered Alertmanager.")
PYTHON_EOF
        then
            echo "Monitoring verification successful."
            return 0
        fi

        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: Monitoring verification failed after $max_attempts attempts."
            return 1
        fi

        echo "Monitoring is not fully healthy yet. Retrying in 10 seconds..."
        sleep 10
    done
}

# ============================================================
# Rollback function
# ============================================================

rollback() {
    echo "============================================"
    echo "MONITORING DEPLOYMENT FAILED"
    echo "Restoring previous configuration..."
    echo "============================================"

    if ! cp "$BACKUP_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml" ||
       ! cp "$BACKUP_DIR/prometheus.yml" "$PROJECT_DIR/monitoring/prometheus/prometheus.yml" ||
       ! cp "$BACKUP_DIR/alert-rules.yml" "$PROJECT_DIR/monitoring/prometheus/alert-rules.yml" ||
       ! cp "$BACKUP_DIR/alertmanager.yml" "$PROJECT_DIR/monitoring/alertmanager/alertmanager.yml"; then

        echo "CRITICAL: Could not restore all previous configuration files."
        return 1
    fi

    if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" \
        --project-directory "$PROJECT_DIR" config --quiet; then

        echo "CRITICAL: Restored Compose configuration is invalid."
        return 1
    fi

    if ! docker compose \
        -f "$PROJECT_DIR/docker-compose.yml" \
        --project-directory "$PROJECT_DIR" \
        up -d --no-deps --force-recreate "${SERVICES_TO_RESTART[@]}"; then

        echo "CRITICAL: Could not restart monitoring services during rollback."
        return 1
    fi

    if ! wait_for_prometheus ||
       ! wait_for_alertmanager ||
       ! verify_restarted_services ||
       ! verify_monitoring; then

        echo "CRITICAL: Previous configuration was restored, but health verification failed."
        return 1
    fi

    echo "ROLLBACK SUCCESS: Previous monitoring configuration restored and verified."
    ROLLBACK_SUCCEEDED=1
}

# ============================================================
# Cleanup and automatic rollback
# ============================================================

on_exit() {
    local exit_code=$?

    trap - EXIT
    set +e

    if [ "$exit_code" -ne 0 ] &&
       [ "$BACKUP_READY" -eq 1 ] &&
       [ "$INSTALL_STARTED" -eq 1 ]; then

        rollback

        if [ "$ROLLBACK_SUCCEEDED" -ne 1 ]; then
            echo "CRITICAL: Rollback needs manual investigation."
            echo "Backup retained at: $BACKUP_DIR"
        fi
    fi

    rm -rf "$TEMP_DIR"

    if [ "$exit_code" -eq 0 ] ||
       [ "$ROLLBACK_SUCCEEDED" -eq 1 ]; then

        if [ -n "$BACKUP_DIR" ]; then
            rm -rf "$BACKUP_DIR"
        fi
    fi

    exit "$exit_code"
}

trap on_exit EXIT

# ============================================================
# Initial checks
# ============================================================

echo "============================================"
echo "DataOps Monitoring Deployment"
echo "Commit: $COMMIT"
echo "============================================"

cd "$PROJECT_DIR"

for required_file in \
    docker-compose.yml \
    monitoring/prometheus/prometheus.yml \
    monitoring/prometheus/alert-rules.yml \
    monitoring/alertmanager/alertmanager.yml \
    .secrets/gmail_app_password; do

    if [ ! -f "$required_file" ]; then
        echo "ERROR: Required production file is missing: $required_file"
        exit 1
    fi
done

# ============================================================
# Download configuration from the exact Git commit
# ============================================================

echo "Downloading configuration from GitHub..."

curl -fsSL "$BASE_URL/docker-compose.yml" \
    -o "$TEMP_DIR/docker-compose.yml"

curl -fsSL "$BASE_URL/monitoring/prometheus/prometheus.yml" \
    -o "$TEMP_DIR/prometheus.yml"

curl -fsSL "$BASE_URL/monitoring/prometheus/alert-rules.yml" \
    -o "$TEMP_DIR/alert-rules.yml"

curl -fsSL "$BASE_URL/monitoring/alertmanager/alertmanager.yml" \
    -o "$TEMP_DIR/alertmanager.yml"

# ============================================================
# Adapt Compose configuration for production
# ============================================================

echo "Preparing production Compose configuration..."

python3 - "$TEMP_DIR/docker-compose.yml" <<'PYTHON_EOF'
import pathlib
import sys

compose_file = pathlib.Path(sys.argv[1])

content = compose_file.read_text()

old = (
    "image: ${ECR_REGISTRY}/"
    "aws-dataops-observability-pipeline-app:${APP_IMAGE_TAG}"
)

new = (
    "image: "
    "173535830796.dkr.ecr.eu-central-1.amazonaws.com/"
    "aws-dataops-observability-pipeline-app:${APP_IMAGE_TAG:-latest}"
)

if content.count(old) != 1:
    print("ERROR: Expected application image reference was not found exactly once.")
    sys.exit(1)

compose_file.write_text(content.replace(old, new))
PYTHON_EOF

# ============================================================
# Validate downloaded configuration
# ============================================================

echo "Validating Docker Compose configuration..."

docker compose \
    --project-directory "$PROJECT_DIR" \
    -f "$TEMP_DIR/docker-compose.yml" \
    config --quiet

echo "Validating Prometheus configuration..."

docker run --rm \
    --entrypoint=promtool \
    -v "$TEMP_DIR/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
    -v "$TEMP_DIR/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro" \
    prom/prometheus:v3.15.0 \
    check config /etc/prometheus/prometheus.yml

docker run --rm \
    --entrypoint=promtool \
    -v "$TEMP_DIR/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro" \
    prom/prometheus:v3.15.0 \
    check rules /etc/prometheus/alert-rules.yml

echo "Validating Alertmanager configuration..."

docker run --rm \
    --entrypoint=amtool \
    -v "$TEMP_DIR/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro" \
    prom/alertmanager:v0.28.1 \
    check-config /etc/alertmanager/alertmanager.yml

# ============================================================
# Compare resolved Compose configurations
# ============================================================

echo "Comparing resolved Compose configurations..."

docker compose \
    --project-directory "$PROJECT_DIR" \
    -f "$PROJECT_DIR/docker-compose.yml" \
    config --format json > "$TEMP_DIR/current-compose.json"

docker compose \
    --project-directory "$PROJECT_DIR" \
    -f "$TEMP_DIR/docker-compose.yml" \
    config --format json > "$TEMP_DIR/incoming-compose.json"

python3 - \
    "$TEMP_DIR/current-compose.json" \
    "$TEMP_DIR/incoming-compose.json" \
    "$TEMP_DIR/services-to-restart" <<'PYTHON_EOF'
import json
import sys

current_path, incoming_path, output_path = sys.argv[1:]

with open(current_path) as file:
    current = json.load(file)

with open(incoming_path) as file:
    incoming = json.load(file)

supported_services = {
    "app",
    "prometheus",
    "alertmanager",
    "grafana",
    "node-exporter",
    "nginx-exporter",
}

allowed_sections = {"name", "services", "volumes", "networks"}

if set(current) != allowed_sections or set(incoming) != allowed_sections:
    print("ERROR: Unexpected or missing top-level Compose sections.")
    print("Current:", sorted(current))
    print("Incoming:", sorted(incoming))
    sys.exit(1)

if current.get("name") != incoming.get("name"):
    print("ERROR: Compose project name changed.")
    sys.exit(1)

current_services = current.get("services", {})
incoming_services = incoming.get("services", {})

if set(current_services) != supported_services:
    print("ERROR: Current Compose configuration does not contain exactly the six expected services.")
    sys.exit(1)

if set(incoming_services) != supported_services:
    print("ERROR: Incoming Compose configuration does not contain exactly the six expected services.")
    sys.exit(1)

for section in ("volumes", "networks"):
    if current.get(section, {}) != incoming.get(section, {}):
        print(f"ERROR: Compose {section} definitions changed.")
        print("This deployment workflow does not manage these changes.")
        sys.exit(1)

if current_services["app"] != incoming_services["app"]:
    print("ERROR: The app service definition has changed.")
    print("Deploy application changes through the existing app CI/CD job.")
    sys.exit(1)

changed_services = sorted(
    service
    for service in supported_services - {"app"}
    if current_services[service] != incoming_services[service]
)

with open(output_path, "w") as file:
    for service in changed_services:
        file.write(service + "\n")

if changed_services:
    print("Changed monitoring services:", ", ".join(changed_services))
else:
    print("No monitoring service definition changes detected.")
PYTHON_EOF

mapfile -t SERVICES_TO_RESTART < "$TEMP_DIR/services-to-restart"

# Configuration-file changes require their respective
# monitoring service to reload its configuration.
if ! cmp -s "$TEMP_DIR/prometheus.yml" monitoring/prometheus/prometheus.yml ||
   ! cmp -s "$TEMP_DIR/alert-rules.yml" monitoring/prometheus/alert-rules.yml; then
    if ! service_is_selected "prometheus"; then
        SERVICES_TO_RESTART+=(prometheus)
    fi
fi

if ! cmp -s "$TEMP_DIR/alertmanager.yml" monitoring/alertmanager/alertmanager.yml; then
    if ! service_is_selected "alertmanager"; then
        SERVICES_TO_RESTART+=(alertmanager)
    fi
fi

if [ "${#SERVICES_TO_RESTART[@]}" -eq 0 ]; then
    echo "No monitoring configuration changes detected."
    echo "No monitoring containers need to be restarted."

    wait_for_prometheus
    wait_for_alertmanager
    verify_monitoring

    echo "MONITORING CONFIGURATION ALREADY UP TO DATE."
    exit 0
fi

echo "Services requiring restart: ${SERVICES_TO_RESTART[*]}"

# ============================================================
# Back up existing production configuration
# ============================================================

echo "Creating configuration backup..."

BACKUP_DIR=$(mktemp -d "$PROJECT_DIR/.monitoring-backup.XXXXXX")

cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml"
cp monitoring/prometheus/prometheus.yml "$BACKUP_DIR/prometheus.yml"
cp monitoring/prometheus/alert-rules.yml "$BACKUP_DIR/alert-rules.yml"
cp monitoring/alertmanager/alertmanager.yml "$BACKUP_DIR/alertmanager.yml"

BACKUP_READY=1

# ============================================================
# Install validated configuration
# ============================================================

echo "Installing new monitoring configuration..."

INSTALL_STARTED=1

install -m 644 "$TEMP_DIR/docker-compose.yml" docker-compose.yml

install -m 644 \
    "$TEMP_DIR/prometheus.yml" \
    monitoring/prometheus/prometheus.yml

install -m 644 \
    "$TEMP_DIR/alert-rules.yml" \
    monitoring/prometheus/alert-rules.yml

install -m 644 \
    "$TEMP_DIR/alertmanager.yml" \
    monitoring/alertmanager/alertmanager.yml

docker compose config --quiet

# ============================================================
# Restart only affected monitoring services
# ============================================================

echo "Restarting: ${SERVICES_TO_RESTART[*]}"

docker compose up -d \
    --no-deps \
    --force-recreate \
    "${SERVICES_TO_RESTART[@]}"

# ============================================================
# Verify deployment
# ============================================================

wait_for_prometheus
wait_for_alertmanager
verify_restarted_services
verify_monitoring

echo "============================================"
echo "MONITORING DEPLOYMENT SUCCESSFUL"
echo "============================================"
