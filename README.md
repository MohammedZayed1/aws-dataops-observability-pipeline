# AWS DataOps Observability & Real-Time Data Pipeline

## Overview

This project is a production-style DevOps and DataOps platform built on AWS as a graduation project.

The platform demonstrates an end-to-end pipeline for infrastructure monitoring, log collection, real-time data streaming, and centralized data storage.

The solution combines Infrastructure as Code, configuration management, observability, cloud services, security, and CI/CD practices.

## Project Objectives

The main objectives of this project are to:

- Build and automate AWS infrastructure using Terraform.
- Configure and manage Linux servers using Ansible.
- Implement infrastructure monitoring using Prometheus and node_exporter.
- Build observability dashboards using Grafana.
- Collect and process logs using Cribl Edge.
- Stream operational data through Amazon Kinesis Data Streams.
- Deliver streaming data to Amazon S3 using Amazon Data Firehose.
- Apply AWS IAM least-privilege security principles.
- Implement CI/CD using GitHub Actions.
- Use GitHub OIDC for secure authentication with AWS.
- Test the complete data pipeline and infrastructure.
- Document the architecture, deployment process, security model, and troubleshooting procedures.

## Architecture

The initial architecture consists of:

- Amazon VPC
- EC2 instances
- Ubuntu 22.04
- Cribl Edge
- node_exporter
- Prometheus
- Grafana
- Amazon Kinesis Data Streams
- Amazon Data Firehose
- Amazon S3
- Terraform
- Ansible
- GitHub Actions

### High-Level Data Flow

```text
EC2 Workers
    │
    ├── node_exporter ───────► Prometheus ───────► Grafana
    │
    └── Cribl Edge
            │
            ▼
    Kinesis Data Streams
            │
            ▼
    Amazon Data Firehose
            │
            ▼
        Amazon S3
```

## Technology Stack

| Category                 | Technology                  |
| ------------------------ | --------------------------- |
| Cloud                    | AWS                         |
| Compute                  | Amazon EC2                  |
| Operating System         | Ubuntu 22.04                |
| Infrastructure as Code   | Terraform                   |
| Configuration Management | Ansible                     |
| Monitoring               | Prometheus                  |
| Metrics                  | node_exporter               |
| Visualization            | Grafana                     |
| Log Collection           | Cribl Edge                  |
| Streaming                | Amazon Kinesis Data Streams |
| Data Delivery            | Amazon Data Firehose        |
| Storage                  | Amazon S3                   |
| CI/CD                    | GitHub Actions              |
| Source Control           | Git / GitHub                |


## Current Phase

Phase 1 - Project Foundation

## Learning Goals

This project is also intended as a practical learning exercise covering:

* Linux administration
* Git and GitHub
* AWS infrastructure
* Networking
* Terraform
* Ansible
* Monitoring and observability
* Log management
* Streaming data pipelines
* IAM and cloud security
* CI/CD
* Infrastructure testing
* Technical documentation


## Observability and Monitoring

The platform implements application and infrastructure observability using Prometheus, Node Exporter, NGINX Prometheus Exporter, and Grafana.

### Monitoring Architecture

```text
EC2 Instance
│
├── DataOps Application
│       │
│       └── NGINX Status Endpoint (:8081)
│                │
│                ▼
│         NGINX Prometheus Exporter
│                │
│                ▼
│            Prometheus
│                │
│                ├── nginx_up
│                └── Node Exporter Metrics
│                         │
│                         ▼
│                      Grafana
│                         │
│                         ▼
│                   Alerting




## CI/CD and Automated Deployment

The project implements an automated CI/CD pipeline using GitHub Actions, Amazon ECR, AWS IAM OIDC, and AWS Systems Manager (SSM).

The pipeline automates Docker image building, testing, publishing, and deployment to the EC2 application server.

### CI/CD Architecture

```text
Developer
    |
    | Push to main branch
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    ├── Build Docker Image
    |
    ├── Run Application Smoke Tests
    |
    ├── Authenticate with AWS using GitHub OIDC
    |
    ├── Push Docker Image to Amazon ECR
    |       |
    |       ├── Commit SHA Tag
    |       └── Latest Tag
    |
    v
AWS Systems Manager (SSM)
    |
    v
EC2 Instance
    |
    ├── Authenticate with Amazon ECR
    |
    ├── Pull New Application Image
    |
    ├── Deploy Using Docker Compose
    |
    └── Verify Application Health
```

### Deployment Workflow

The GitHub Actions workflow (`.github/workflows/ci.yml`) performs the following operations:

1. **Build:** Builds the Docker image from the application source code.
2. **Smoke Testing:** Starts a temporary application container and verifies that the application responds successfully.
3. **AWS Authentication:** Uses GitHub Actions OIDC to assume an AWS IAM role without storing long-lived AWS access keys in GitHub Secrets.
4. **Image Publishing:** Pushes the Docker image to Amazon ECR using both the Git commit SHA and `latest` tags.
5. **Remote Deployment:** Uses AWS Systems Manager Run Command to execute deployment commands on the EC2 instance.
6. **Health Verification:** Checks the Docker container health status before considering the deployment successful.

### Automated Rollback and Recovery

The deployment script includes an automatic rollback mechanism designed to recover from deployment failures.

Before deploying a new version, the script captures the currently running application's Docker image.

If the new deployment fails during image pulling, container startup, or health verification, the rollback handler attempts to:

1. Restore the previous application image.
2. Restart the application using Docker Compose.
3. Wait for the restored container to become healthy.
4. Report whether recovery succeeded or failed.

The deployment process returns a failure status even when rollback succeeds. This ensures that GitHub Actions accurately reports an unsuccessful deployment while distinguishing successful recovery from deployment success.

### Rollback Testing and Verification

The rollback mechanism was tested through a controlled failure simulation.

During the test:

- A new application image was successfully pulled from Amazon ECR.
- A simulated deployment failure was triggered before replacing the running application container.
- The rollback handler restored the previously deployed image.
- The restored application passed its Docker health check.
- An independent verification confirmed that the application returned HTTP 200.

**Recovery verification results:**

| Verification | Result |
|---|---|
| New image pull | Successful |
| Failure detection | Successful |
| Rollback execution | Successful |
| Previous image restoration | Successful |
| Container health | Healthy |
| HTTP response | 200 OK |

The test confirmed that the rollback handler successfully restores the previous application version after the simulated failure.

### Deployment Security

The CI/CD implementation follows several security practices:

- GitHub OIDC authentication instead of long-lived AWS access keys.
- IAM permissions scoped to the required AWS resources and operations.
- AWS Systems Manager for remote server management.
- No publicly exposed SSH access to the EC2 instance.
- Amazon ECR for private Docker image storage.



### Author

**Mohammed Zayed**

DevOps Engineer | Software Engineer 
