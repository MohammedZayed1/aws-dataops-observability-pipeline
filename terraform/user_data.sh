#!/bin/bash

set -e

# Log all user-data output
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting EC2 bootstrap..."

# Wait for network connectivity
until curl -fsS https://github.com > /dev/null; do
  echo "Waiting for network..."
  sleep 5
done

# Update packages
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
  ca-certificates \
  curl \
  git

# Install Docker
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create application directory
mkdir -p /opt/dataops/app

# Clone project
cd /opt/dataops/app

git clone https://github.com/MohammedZayed1/aws-dataops-observability-pipeline.git

cd /opt/dataops/app/aws-dataops-observability-pipeline

# Build application image
docker build -t dataops-app:2.0 .

# Start the complete observability stack
docker compose up -d

echo "EC2 bootstrap completed successfully."
