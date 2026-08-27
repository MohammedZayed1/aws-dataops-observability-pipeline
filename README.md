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
- Amazon Linux 2023
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
| Operating System         | Amazon Linux 2023           |
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

Phase 1 — Project Foundation

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

### Author

**Mohammed Zayed**

DevOps Engineer | Software Engineer 
