# AWS DataOps Observability Pipeline

An AWS-based DevOps and DataOps graduation project demonstrating Infrastructure as Code, containerized application deployment, automated CI/CD, infrastructure monitoring, alerting, and deployment recovery.

## 1. Project Overview

The AWS DataOps Observability Pipeline is a cloud-based platform built to demonstrate practical DevOps and DataOps engineering practices.

The current implementation focuses on provisioning AWS infrastructure, deploying a containerized NGINX application, automating application and monitoring deployments, and implementing an observability stack using Prometheus, Grafana, Node Exporter, NGINX Prometheus Exporter, and Alertmanager.

The project also establishes a foundation for future data engineering capabilities, including log collection, streaming, and centralized data storage.

### Project Objectives

- Provision AWS infrastructure using Terraform.
- Deploy and manage a containerized application using Docker and Docker Compose.
- Implement automated CI/CD using GitHub Actions.
- Authenticate securely with AWS using GitHub OIDC.
- Store and distribute Docker images using Amazon ECR.
- Deploy applications and monitoring configurations through AWS Systems Manager (SSM).
- Monitor infrastructure and application metrics using Prometheus.
- Visualize operational metrics using Grafana.
- Configure infrastructure alerting and email notifications.
- Implement automated deployment validation and rollback mechanisms.
- Document architecture, testing, security, and operational procedures.

## 2. Architecture

### Current Architecture

The current platform consists of AWS infrastructure, a Docker-based application environment, and an observability stack.

```text
                         Developer
                             |
                             v
                       GitHub Repository
                             |
                             v
                       GitHub Actions
                             |
                  +----------+----------+
                  |                     |
                  v                     v
             Application CI/CD    Monitoring Deployment
                  |                     |
                  v                     v
             Amazon ECR          AWS Systems Manager
                  |                     |
                  +----------+----------+
                             |
                             v
                        Amazon EC2
                             |
                    Docker Compose Stack
                             |
          +------------------+------------------+
          |                  |                  |
          v                  v                  v
      NGINX App         Node Exporter       Prometheus
          |                                     |
          v                                     v
    NGINX Exporter                         Alert Rules
          |                                     |
          +------------------+------------------+
                             |
                  +----------+----------+
                  |                     |
                  v                     v
               Grafana              Alertmanager
             Dashboards            Email Alerts
```

### AWS Infrastructure

Terraform manages the main AWS infrastructure components:

- Amazon VPC.
- Public and private subnets.
- Internet Gateway and route tables.
- EC2 security group.
- Amazon EC2 instance.
- EC2 IAM role and instance profile.
- Amazon ECR repository.
- GitHub Actions OIDC identity provider.
- GitHub Actions IAM role and policies.

### Application Environment

The application is a containerized NGINX web application.

- Application container: `dataops-app`
- Host application port: `8080`
- Container port: `80`
- NGINX status endpoint: `8081`
- Application health check: Docker health check using the local HTTP endpoint.

## 3. Technology Stack

| Category | Technology |
|---|---|
| Cloud Provider | AWS |
| Compute | Amazon EC2 |
| Networking | Amazon VPC |
| Containerization | Docker |
| Container Orchestration | Docker Compose |
| Infrastructure as Code | Terraform |
| Web Server | NGINX |
| Container Registry | Amazon ECR |
| Remote Management | AWS Systems Manager |
| CI/CD | GitHub Actions |
| Authentication | GitHub OIDC and AWS IAM |
| Monitoring | Prometheus |
| Infrastructure Metrics | Node Exporter |
| Application Metrics | NGINX Prometheus Exporter |
| Visualization | Grafana |
| Alerting | Prometheus Alertmanager |
| Version Control | Git and GitHub |
| Operating System | Ubuntu 22.04 |

## 4. Observability and Monitoring

The project implements infrastructure and application monitoring through a Docker-based observability stack.

### Monitoring Components

| Component | Purpose |
|---|---|
| Prometheus | Metrics collection, querying, and alert evaluation |
| Node Exporter | Infrastructure and host-level metrics |
| NGINX Prometheus Exporter | NGINX application metrics |
| Grafana | Metrics visualization and dashboards |
| Alertmanager | Alert routing and email notifications |

### Prometheus Scrape Targets

Prometheus is configured with a 15-second scrape interval and monitors three targets:

| Job | Target | Purpose |
|---|---|---|
| prometheus | `localhost:9090` | Prometheus self-monitoring |
| node-exporter | `node-exporter:9100` | Host infrastructure metrics |
| nginx-exporter | `nginx-exporter:9113` | NGINX metrics |

### Alert Rules

Four Prometheus alert rules are configured:

| Alert | Condition | Severity |
|---|---|---|
| HighCPUUsage | CPU usage exceeds 80% for 5 minutes | Warning |
| HighMemoryUsage | Memory usage exceeds 85% for 5 minutes | Warning |
| LowDiskSpace | Available root filesystem space falls below 15% for 5 minutes | Critical |
| MonitoringTargetDown | A Prometheus scrape target is unavailable for 2 minutes | Critical |

### Alert Notifications

Alertmanager is configured to send email notifications through Gmail SMTP.

The configuration supports:

- Alert grouping by alert name and instance.
- A 30-second initial group wait.
- A 5-minute group interval.
- A 4-hour repeat interval.
- Notifications when alerts are resolved.

The Gmail App Password is stored in a local secret file and mounted into the Alertmanager container. It must not be committed to Git.

### Persistent Monitoring Data

Docker volumes provide persistent storage for:

- Prometheus time-series data.
- Grafana data.
- Alertmanager data.

This helps preserve monitoring data and application configuration across container recreation.

## 5. CI/CD and Automated Application Deployment

The project uses GitHub Actions to automate application building, testing, publishing, and deployment.

### Application Deployment Workflow

```text
Developer Pushes to main
          |
          v
     GitHub Actions
          |
          v
     Build Docker Image
          |
          v
  Start Temporary Container
          |
          v
    HTTP Smoke Test
          |
          v
 Authenticate Using OIDC
          |
          v
       Amazon ECR
          |
          v
  Push SHA and latest Tags
          |
          v
    AWS Systems Manager
          |
          v
       Amazon EC2
          |
          v
   Deploy Using Docker Compose
          |
          v
    Verify Container Health
```

The workflow (`.github/workflows/ci.yml`) performs the following operations:

1. Checks out the repository.
2. Builds the Docker image.
3. Starts a temporary container for testing.
4. Performs an HTTP smoke test.
5. Authenticates to AWS using GitHub OIDC.
6. Pushes the image to Amazon ECR using the commit SHA and `latest` tags.
7. Triggers remote deployment through AWS Systems Manager.
8. Verifies the new application container's health.

### Application Rollback

The application deployment process includes a rollback mechanism.

If deployment fails during image pulling, container startup, or health verification, the deployment handler attempts to:

1. Restore the previously deployed application image.
2. Restart the application using Docker Compose.
3. Wait for the restored container to become healthy.
4. Report the deployment and recovery results.

The deployment remains marked as failed in GitHub Actions even if rollback succeeds. This distinguishes a failed deployment with successful recovery from a successful deployment.

## 6. Automated Monitoring Configuration Deployment

In addition to application deployment, the project implements a separate GitHub Actions job for monitoring configuration deployment.

The `deploy-monitoring` job runs after the application CI/CD job when changes are pushed to the `main` branch.

### Deployment Process

The monitoring deployment script is located at:

`.github/scripts/deploy-monitoring.sh`

The script performs several safeguards before applying changes:

1. Downloads monitoring configuration files from the exact Git commit.
2. Prepares the production Docker Compose configuration.
3. Validates Docker Compose configuration.
4. Validates Prometheus configuration and alert rules using `promtool`.
5. Validates Alertmanager configuration using `amtool`.
6. Compares resolved Compose configurations.
7. Protects the application service, persistent volumes, and network configuration from unintended changes.
8. Identifies the monitoring services that need to be restarted.
9. Creates backups of the existing configuration files.
10. Applies the new configuration and verifies monitoring health.

### Monitoring Configuration Rollback

If monitoring deployment fails after installation begins, the script attempts to restore the previous versions of:

- `docker-compose.yml`
- `monitoring/prometheus/prometheus.yml`
- `monitoring/prometheus/alert-rules.yml`
- `monitoring/alertmanager/alertmanager.yml`

After restoring the files, it verifies Prometheus and Alertmanager readiness, Prometheus scrape targets, and alert rules.

If rollback cannot be successfully verified, the backup is retained for manual investigation.

This provides a recovery mechanism specifically for monitoring configuration changes, separate from the application image rollback process.

## 7. Testing and Verification

Testing is performed at application, infrastructure, monitoring, and deployment levels.

### Application and Monitoring Verification

The production environment was verified through:

- Application HTTP response checks.
- Docker container health checks.
- Grafana health endpoint checks.
- Prometheus target status checks.
- Prometheus alert rule validation.
- Alertmanager readiness and discovery checks.

The following monitoring targets were verified as healthy:

- Prometheus.
- Node Exporter.
- NGINX Prometheus Exporter.

The four configured alert rules were also verified as loaded and healthy.

### Application Rollback Testing

A controlled application deployment failure was simulated to verify that the previously deployed Docker image could be restored and the application could return to a healthy state.

### Monitoring Rollback Testing

A separate controlled rollback test was performed using an isolated Bash test harness.

Two scenarios were tested:

| Scenario | Expected Behavior | Result |
|---|---|---|
| Deployment failure with successful rollback | Restore original configuration and remove backup | PASS |
| Deployment failure with unsuccessful rollback verification | Restore original files and retain backup | PASS |

The test verified restoration and backup handling for all four monitoring configuration files.

**Important testing limitation:** The monitoring rollback test used a standalone harness reproducing the rollback and cleanup logic. Docker Compose operations, monitoring service restarts, and actual Prometheus and Alertmanager health checks were simulated. It was not a full end-to-end failure test of the production deployment script.

Detailed results are available in:

`docs/testing/rollback-testing.md`

## 8. Repository Structure

```text
aws-dataops-observability-pipeline/
│
├── app/
│   └── index.html
│
├── docs/
│   └── testing/
│       └── rollback-testing.md
│
├── monitoring/
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   │
│   └── prometheus/
│       ├── prometheus.yml
│       └── alert-rules.yml
│
├── terraform/
│   ├── ecr.tf
│   ├── github_actions.tf
│   ├── iam.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── user_data.sh
│   └── variables.tf
│
├── .github/
│   ├── scripts/
│   │   └── deploy-monitoring.sh
│   │
│   └── workflows/
│       └── ci.yml
│
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
├── .gitignore
└── README.md
```

## 9. Prerequisites

To work with or reproduce the project, the following tools and services are required:

- AWS account.
- AWS CLI.
- Terraform.
- Docker Engine.
- Docker Compose.
- Git.
- GitHub repository.
- Ubuntu-based Linux environment or WSL.

Additional AWS and GitHub configuration is required for the automated deployment workflow:

- An EC2 instance managed through AWS Systems Manager.
- An EC2 IAM role with the required permissions.
- An Amazon ECR repository.
- A GitHub OIDC identity provider and IAM role.
- GitHub Actions permissions to request an OIDC token.
- The required application and deployment configuration.
- A locally managed Gmail App Password for Alertmanager email notifications.

## 10. Security Practices

The project applies several security practices:

- GitHub OIDC authentication instead of long-lived AWS access keys.
- IAM policies scoped to the required deployment operations and resources.
- AWS Systems Manager for remote EC2 management instead of public SSH access.
- Amazon ECR for private Docker image storage.
- Local secret-file handling for the Alertmanager SMTP credential.
- Persistent monitoring data volumes.
- Validation of configuration before deployment.
- Automatic rollback when deployment verification fails.

**Never commit credentials, AWS access keys, Gmail App Passwords, Terraform state files, or other sensitive configuration to GitHub.**

## 11. Future Development

The broader DataOps vision includes additional data collection and streaming capabilities.

Potential future extensions include:

- Ansible-based configuration management.
- Cribl Edge for log collection and processing.
- Amazon Kinesis Data Streams for real-time data streaming.
- Amazon Data Firehose for data delivery.
- Amazon S3 for centralized data storage.
- Automated data pipeline testing and validation.
- Expanded dashboards and operational analytics.

These are planned extensions and are not presented as currently deployed components.

## 12. Author

**Mohammed Zayed**

DevOps Engineer | Software Engineer

GitHub: [MohammedZayed1](https://github.com/MohammedZayed1)

Project Repository: [aws-dataops-observability-pipeline](https://github.com/MohammedZayed1/aws-dataops-observability-pipeline)
