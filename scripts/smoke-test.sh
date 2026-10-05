#!/usr/bin/env bash
set -Eeuo pipefail
container=$(docker run -d --read-only --cap-drop ALL --security-opt no-new-privileges "$1")
trap 'docker rm -f "$container" >/dev/null' EXIT
for attempt in {1..30}; do
  status=$(docker inspect --format '{{.State.Health.Status}}' "$container")
  if [[ "$status" == healthy ]]; then exit 0; fi
  if [[ "$status" == unhealthy ]]; then break; fi
  sleep 2
done
docker logs "$container"
echo 'Container failed its health check' >&2
exit 1
