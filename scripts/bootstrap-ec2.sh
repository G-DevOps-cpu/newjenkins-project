#!/usr/bin/env bash
# Run once with sudo on a fresh Amazon Linux 2023 x86_64 deployment instance.
set -Eeuo pipefail
dnf install -y docker util-linux
systemctl enable --now docker
usermod -aG docker ec2-user
echo 'Reconnect your SSH session before running docker as ec2-user.'
