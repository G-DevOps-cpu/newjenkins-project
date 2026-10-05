#!/usr/bin/env bash
# Runs on EC2. stdin is a docker-save archive; argument is its expected image tag.
set -Eeuo pipefail
image=${1:?Expected image tag}
[[ "$image" =~ ^classroom-app:[a-zA-Z0-9_.-]+$ ]] || exit 2
mkdir -p "$HOME/.classroom"
exec 9>"$HOME/.classroom/deploy.lock"
flock -w 180 9 || { echo 'Another deployment holds the lock' >&2; exit 1; }
docker load
docker image inspect "$image" >/dev/null
name=classroom-app
previous=classroom-app-previous
wait_healthy() {
  local status
  for attempt in {1..30}; do
    status=$(docker inspect --format '{{.State.Health.Status}}' "$name")
    [[ "$status" == healthy ]] && return 0
    [[ "$status" == unhealthy ]] && return 1
    sleep 2
  done
  return 1
}
# Recover a backup left by an interrupted earlier deployment before making changes.
if docker container inspect "$previous" >/dev/null 2>&1; then
  if docker container inspect "$name" >/dev/null 2>&1 && wait_healthy; then
    docker rm -f "$previous"
  else
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker rename "$previous" "$name"
    docker start "$name"
    wait_healthy || { echo 'Previous deployment recovery failed' >&2; exit 1; }
  fi
fi
had_previous=false
rollback() {
  trap - ERR HUP INT TERM
  set +e
  docker logs "$name" >&2
  docker rm -f "$name"
  if [[ "$had_previous" == true ]]; then
    docker rename "$previous" "$name" && docker start "$name"
    if wait_healthy; then
      echo 'Previous version restored' >&2
    else
      echo 'ROLLBACK FAILED: operator intervention required' >&2
    fi
  else
    echo 'First deployment failed; there is no previous version' >&2
  fi
  exit 1
}
if docker container inspect "$name" >/dev/null 2>&1; then
  docker rename "$name" "$previous"
  had_previous=true
fi
trap rollback ERR HUP INT TERM
if [[ "$had_previous" == true ]]; then docker stop "$previous"; fi
docker run -d --name "$name" --restart unless-stopped \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --memory 256m --cpus 1 --log-opt max-size=10m --log-opt max-file=3 \
  -p 80:3000 -e "APP_VERSION=${image#*:}" "$image"
wait_healthy
trap - ERR HUP INT TERM
echo "Healthy deployment: $image"
# Keep the stopped previous container until the next successful deployment cycle.
