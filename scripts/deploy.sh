#!/usr/bin/env bash
set -Eeuo pipefail
host=${1:?Expected host}
image=${2:?Expected image}
[[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Use a hostname or IPv4 address' >&2; exit 2; }
[[ "$image" =~ ^classroom-app:[a-zA-Z0-9_.-]+$ ]] || exit 2
: "${KNOWN_HOSTS:?Bind the Jenkins known-hosts secret file}"
options=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$KNOWN_HOSTS")
remote_script=$(ssh "${options[@]}" "ec2-user@$host" 'mktemp /tmp/classroom-deploy.XXXXXXXX')
[[ "$remote_script" =~ ^/tmp/classroom-deploy\.[a-zA-Z0-9]+$ ]] || exit 2
trap 'ssh "${options[@]}" "ec2-user@$host" "rm -f -- $remote_script" || true' EXIT
scp "${options[@]}" scripts/deploy-remote.sh "ec2-user@$host:$remote_script"
ssh "${options[@]}" "ec2-user@$host" "bash $remote_script $image" < dist/image.tar
