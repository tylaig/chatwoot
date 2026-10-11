#!/usr/bin/env bash
set -Eeuo pipefail

STACK_NAME="${STACK_NAME:-chatwoot_gamessafari}"
APP_SERVICE="${APP_SERVICE:-${STACK_NAME}_chatwoot_app}"
SIDEKIQ_SERVICE="${SIDEKIQ_SERVICE:-${STACK_NAME}_chatwoot_sidekiq}"
PUBLIC_URL="${PUBLIC_URL:-https://inbox.gamessafari.com}"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/chatwoot-deploy/backups}"
STATE_ROOT="${STATE_ROOT:-/opt/chatwoot-deploy}"
LOCK_FILE="${LOCK_FILE:-/var/lock/chatwoot-gamessafari-deploy.lock}"
IMAGE_REF="${1:-${IMAGE_REF:-}}"
EXPECTED_DIGEST="${EXPECTED_DIGEST:-}"
GITHUB_SHA="${GITHUB_SHA:-unknown}"

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
fatal() { log "ERROR: $*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || fatal "Missing required command: $1"; }

[[ -n "$IMAGE_REF" ]] || fatal "Usage: IMAGE_REF=<image@digest> $0 (or pass image@digest as first argument)"
[[ "$IMAGE_REF" == *@sha256:* ]] || fatal "IMAGE_REF must be immutable image@sha256 digest, got: $IMAGE_REF"
[[ $EUID -eq 0 ]] || fatal "This deploy helper must run as root (Docker Swarm + backup access)."

require docker
require flock
require awk
require sed
require grep
require curl
require gzip
require tar

mkdir -p "$STATE_ROOT" "$BACKUP_ROOT" "$(dirname "$LOCK_FILE")"
chmod 700 "$STATE_ROOT" "$BACKUP_ROOT"

exec 9>"$LOCK_FILE"
flock -n 9 || fatal "Another Chatwoot production deploy is already running."

if [[ -n "$EXPECTED_DIGEST" && "$IMAGE_REF" != *"@$EXPECTED_DIGEST" ]]; then
  fatal "IMAGE_REF digest does not match EXPECTED_DIGEST"
fi

log "Starting Chatwoot Swarm deploy for ${IMAGE_REF} (source ${GITHUB_SHA})"
[[ "$(docker info --format '{{.Swarm.LocalNodeState}}')" == "active" ]] || fatal "Docker Swarm is not active"
[[ "$(docker info --format '{{.Swarm.ControlAvailable}}')" == "true" ]] || fatal "This node is not a Swarm manager"

docker service inspect "$APP_SERVICE" >/dev/null || fatal "App service not found: $APP_SERVICE"
docker service inspect "$SIDEKIQ_SERVICE" >/dev/null || fatal "Sidekiq service not found: $SIDEKIQ_SERVICE"

current_app_image="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$APP_SERVICE")"
current_sidekiq_image="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$SIDEKIQ_SERVICE")"
log "Current app image: ${current_app_image}"
log "Current sidekiq image: ${current_sidekiq_image}"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${BACKUP_ROOT}/${stamp}-${GITHUB_SHA:0:12}"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

docker service inspect "$APP_SERVICE" > "${backup_dir}/${APP_SERVICE}.service.json"
docker service inspect "$SIDEKIQ_SERVICE" > "${backup_dir}/${SIDEKIQ_SERVICE}.service.json"
printf '%s\n' "$current_app_image" > "${backup_dir}/previous_app_image.txt"
printf '%s\n' "$current_sidekiq_image" > "${backup_dir}/previous_sidekiq_image.txt"
printf '%s\n' "$IMAGE_REF" > "${backup_dir}/target_image.txt"
chmod 600 "${backup_dir}"/*
ln -sfn "$backup_dir" "${BACKUP_ROOT}/latest"

app_container="$(docker ps --filter "label=com.docker.swarm.service.name=${APP_SERVICE}" --format '{{.ID}}' | head -n1)"
[[ -n "$app_container" ]] || fatal "No running app container found for ${APP_SERVICE}"

log "Collecting pre-deploy data counts"
docker exec "$app_container" sh -lc 'bundle exec rails runner "puts({account_count: Account.count, user_count: User.count, inbox_count: Inbox.count, conversation_count: Conversation.count}.to_json)"' \
  > "${backup_dir}/counts_before.json" 2> "${backup_dir}/counts_before.stderr" || fatal "Could not collect pre-deploy counts"
cat "${backup_dir}/counts_before.json"

log "Checking current container has no pending migrations"
docker exec "$app_container" sh -lc 'bundle exec rails db:abort_if_pending_migrations' > "${backup_dir}/pending_migrations_before.out" 2>&1 || true

log "Creating verified PostgreSQL dump inside current app environment"
docker exec "$app_container" sh -lc '
  set -eu
  : "${POSTGRES_HOST:?}" "${POSTGRES_USERNAME:?}" "${POSTGRES_PASSWORD:?}" "${POSTGRES_DATABASE:?}"
  export PGPASSWORD="$POSTGRES_PASSWORD"
  pg_dump -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5432}" -U "$POSTGRES_USERNAME" -d "$POSTGRES_DATABASE" -Fc --no-owner --no-acl -f /tmp/chatwoot-predeploy.dump
  pg_restore -l /tmp/chatwoot-predeploy.dump >/tmp/chatwoot-predeploy.dump.list
  test -s /tmp/chatwoot-predeploy.dump
  test -s /tmp/chatwoot-predeploy.dump.list
' || fatal "PostgreSQL dump failed"
docker cp "${app_container}:/tmp/chatwoot-predeploy.dump" "${backup_dir}/chatwoot-predeploy.dump"
docker cp "${app_container}:/tmp/chatwoot-predeploy.dump.list" "${backup_dir}/chatwoot-predeploy.dump.list"
docker exec "$app_container" rm -f /tmp/chatwoot-predeploy.dump /tmp/chatwoot-predeploy.dump.list >/dev/null 2>&1 || true
test -s "${backup_dir}/chatwoot-predeploy.dump" || fatal "Backup dump is empty"
test -s "${backup_dir}/chatwoot-predeploy.dump.list" || fatal "Backup dump verification list is empty"
chmod 600 "${backup_dir}/chatwoot-predeploy.dump" "${backup_dir}/chatwoot-predeploy.dump.list"
log "Backup created at ${backup_dir}"

log "Pulling target image"
docker pull "$IMAGE_REF" >/dev/null

log "Inspecting pending migration delta in target image (stops on destructive pending migration patterns)"
docker exec "$app_container" sh -lc '
  set -eu
  : "${POSTGRES_HOST:?}" "${POSTGRES_USERNAME:?}" "${POSTGRES_PASSWORD:?}" "${POSTGRES_DATABASE:?}"
  export PGPASSWORD="$POSTGRES_PASSWORD"
  psql -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5432}" -U "$POSTGRES_USERNAME" -d "$POSTGRES_DATABASE" -Atc "select version from schema_migrations order by version"
' > "${backup_dir}/applied_schema_versions.txt" || fatal "Could not read applied schema migrations"
docker run --rm --entrypoint sh \
  -v "${backup_dir}/applied_schema_versions.txt:/tmp/applied_schema_versions.txt:ro" \
  "$IMAGE_REF" -lc '
  set -eu
  : > /tmp/pending_migrations.txt
  for f in db/migrate/*.rb; do
    b=$(basename "$f")
    v=${b%%_*}
    if ! grep -qx "$v" /tmp/applied_schema_versions.txt; then
      printf "%s\n" "$f" >> /tmp/pending_migrations.txt
    fi
  done
  cat /tmp/pending_migrations.txt
  if [ -s /tmp/pending_migrations.txt ] && xargs -r grep -InE "remove_column|drop_table|drop_column|drop_join_table|change_column_null|execute[ (].*(DROP|DELETE|TRUNCATE|ALTER)" < /tmp/pending_migrations.txt; then
    echo "Potentially destructive pending migration pattern found." >&2
    exit 42
  fi
' > "${backup_dir}/target_migration_scan.txt" 2>&1 || {
  cat "${backup_dir}/target_migration_scan.txt" >&2
  fatal "Migration scan failed or found a destructive pending migration pattern"
}

log "Preparing database inside current app container using target image code copied temporarily"
docker create --name "${STACK_NAME}_deploy_extract_${stamp}" "$IMAGE_REF" >/dev/null
rm -rf "${backup_dir}/target_app"
mkdir -p "${backup_dir}/target_app"
docker cp "${STACK_NAME}_deploy_extract_${stamp}:/app/." "${backup_dir}/target_app"
docker rm "${STACK_NAME}_deploy_extract_${stamp}" >/dev/null
docker exec "$app_container" rm -rf /tmp/deploy_target_app >/dev/null 2>&1 || true
docker cp "${backup_dir}/target_app/." "${app_container}:/tmp/deploy_target_app"
set +e
prepare_output="$(docker exec -w /tmp/deploy_target_app "$app_container" sh -lc 'bundle exec rails db:chatwoot_prepare' 2>&1)"
prepare_rc=$?
set -e
printf '%s\n' "$prepare_output" > "${backup_dir}/prepare_container.log"
docker exec "$app_container" rm -rf /tmp/deploy_target_app >/dev/null 2>&1 || true
rm -rf "${backup_dir}/target_app"
[[ $prepare_rc -eq 0 ]] || { tail -n 200 "${backup_dir}/prepare_container.log" >&2 || true; fatal "Migration prepare container failed"; }

: <<'OLD_PREPARE_SERVICE_DISABLED'
set +e
prepare_output="$(docker service create \
  --name "${STACK_NAME}_deploy_prepare_${stamp}" \
  --restart-condition none \
  --network GamesSafariNet \
  --with-registry-auth \
  --env DEPLOY_FROM_SERVICE="$APP_SERVICE" \
  --env IMAGE_REF="$IMAGE_REF" \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --entrypoint sh \
  docker:27-cli \
  -lc 'set -eu; src=$(docker ps --filter label=com.docker.swarm.service.name="$DEPLOY_FROM_SERVICE" --format "{{.ID}}" | head -n1); test -n "$src"; docker inspect "$src" --format "{{range .Config.Env}}{{println .}}{{end}}" > /tmp/src.env; docker run --rm --network container:"$src" --env-file /tmp/src.env "$IMAGE_REF" sh -lc "bundle exec rails db:chatwoot_prepare"' 2>&1)"
prepare_rc=$?
set -e
printf '%s\n' "$prepare_output" > "${backup_dir}/prepare_service_create.out"
[[ $prepare_rc -eq 0 ]] || fatal "Could not create migration prepare service: ${prepare_output}"
prepare_id="$(awk 'NF{last=$NF} END{print last}' "${backup_dir}/prepare_service_create.out")"
[[ -n "$prepare_id" ]] || fatal "Could not determine prepare service id"

prepare_service="${STACK_NAME}_deploy_prepare_${stamp}"
prepare_status="unknown"
for _ in $(seq 1 120); do
  state="$(docker service ps --no-trunc --format '{{.CurrentState}}' "$prepare_service" 2>/dev/null | head -n1 || true)"
  err="$(docker service ps --no-trunc --format '{{.Error}}' "$prepare_service" 2>/dev/null | head -n1 || true)"
  printf '%s state=%s error=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$state" "$err" >> "${backup_dir}/prepare_service_watch.log"
  if [[ "$state" == Complete* ]]; then prepare_status=complete; break; fi
  if [[ "$state" == Failed* || "$state" == Rejected* || "$state" == Shutdown* && -n "$err" ]]; then prepare_status=failed; break; fi
  sleep 5
done
docker service logs --raw "$prepare_service" > "${backup_dir}/prepare_service.log" 2>&1 || true
docker service rm "$prepare_service" >/dev/null 2>&1 || true
[[ "$prepare_status" == "complete" ]] || { tail -n 200 "${backup_dir}/prepare_service.log" >&2 || true; fatal "Migration prepare service did not complete (status=${prepare_status})"; }
OLD_PREPARE_SERVICE_DISABLED

log "Updating Swarm services to exact image digest"
docker service update --with-registry-auth --image "$IMAGE_REF" --update-order stop-first "$SIDEKIQ_SERVICE" >/dev/null
docker service update --with-registry-auth --image "$IMAGE_REF" --update-order stop-first "$APP_SERVICE" >/dev/null

wait_service() {
  local svc="$1"
  log "Waiting for ${svc} convergence"
  for _ in $(seq 1 120); do
    local desired running updating failed
    desired="$(docker service inspect -f '{{.Spec.Mode.Replicated.Replicas}}' "$svc")"
    running="$(docker service ps --filter desired-state=running --format '{{.CurrentState}}' "$svc" | grep -c '^Running' || true)"
    updating="$(docker service inspect -f '{{.UpdateStatus.State}}' "$svc" 2>/dev/null || true)"
    failed="$(docker service ps --filter desired-state=running --no-trunc --format '{{.CurrentState}} {{.Error}}' "$svc" | grep -Ei 'Failed|Rejected' || true)"
    printf '%s desired=%s running=%s update=%s failed=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$desired" "$running" "$updating" "$failed" >> "${backup_dir}/${svc}.watch.log"
    if [[ "$running" == "$desired" && -z "$failed" && ( "$updating" == "completed" || "$updating" == "" ) ]]; then
      return 0
    fi
    sleep 5
  done
  docker service ps --no-trunc "$svc" >&2 || true
  return 1
}
wait_service "$SIDEKIQ_SERVICE" || fatal "Sidekiq service failed to converge"
wait_service "$APP_SERVICE" || fatal "App service failed to converge"

new_app_image="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$APP_SERVICE")"
new_sidekiq_image="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$SIDEKIQ_SERVICE")"
[[ "$new_app_image" == "$IMAGE_REF" ]] || fatal "App image mismatch: ${new_app_image}"
[[ "$new_sidekiq_image" == "$IMAGE_REF" ]] || fatal "Sidekiq image mismatch: ${new_sidekiq_image}"

log "Waiting for public HTTP health"
for _ in $(seq 1 60); do
  code="$(curl -kfsS -o /dev/null -w '%{http_code}' "${PUBLIC_URL}/api" 2>/dev/null || true)"
  printf '%s http_code=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$code" >> "${backup_dir}/http_health.log"
  [[ "$code" =~ ^(200|301|302|401|404)$ ]] && break
  sleep 5
done
[[ "$code" =~ ^(200|301|302|401|404)$ ]] || fatal "Public HTTP health check failed"

new_app_container="$(docker ps --filter "label=com.docker.swarm.service.name=${APP_SERVICE}" --format '{{.ID}}' | head -n1)"
[[ -n "$new_app_container" ]] || fatal "No running app container after update"
docker exec "$new_app_container" sh -lc 'bundle exec rails runner "puts({account_count: Account.count, user_count: User.count, inbox_count: Inbox.count, conversation_count: Conversation.count}.to_json)"' \
  > "${backup_dir}/counts_after.json" 2> "${backup_dir}/counts_after.stderr" || fatal "Could not collect post-deploy counts"
log "Post-deploy data counts:"
cat "${backup_dir}/counts_after.json"

cat > "${backup_dir}/rollback.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
docker service update --with-registry-auth --image '${current_sidekiq_image}' '${SIDEKIQ_SERVICE}'
docker service update --with-registry-auth --image '${current_app_image}' '${APP_SERVICE}'
EOF
chmod 700 "${backup_dir}/rollback.sh"

log "Deploy completed successfully"
log "Target image: ${IMAGE_REF}"
log "Services: ${APP_SERVICE}, ${SIDEKIQ_SERVICE}"
log "Backup/rollback directory: ${backup_dir}"
