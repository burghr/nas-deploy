#!/usr/bin/env bash
# Keep each app folder on this host equal to its GitHub branch.
# Cron runs this script every few minutes. See README.md.
#
# For each folder in APPS:
#   1. Fetch the branch from origin.
#   2. If HEAD already matches, do nothing.
#   3. If not, reset the folder to origin/BRANCH.
#   4. If the folder has an executable on-deploy.sh, run it.
#      Otherwise, if the folder has a compose file, run "docker compose up -d --build".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/.env"
[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE, copy .env.example" >&2; exit 1; }
# shellcheck source=/dev/null
. "$ENV_FILE"

APPS_ROOT="${APPS_ROOT:-$HOME}"
BRANCH="${BRANCH:-main}"
DOCKER="${DOCKER:-sudo -n docker}"
LOG_FILE="${LOG_FILE:-$HERE/deploy.log}"
: "${APPS:?set APPS in $ENV_FILE}"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"; }

# Allow one run at a time. A second run exits at once.
exec 9>"$HERE/.lock"
flock -n 9 || exit 0

# Keep the log under about 1 MB.
if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE")" -gt 1000000 ]; then
  tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# Bring one folder to origin/BRANCH. Print "changed" when HEAD moved.
sync_repo() {
  local dir="$1" before after
  if ! git -C "$dir" fetch -q origin "$BRANCH"; then
    log "$dir: fetch failed"
    return 0
  fi
  before="$(git -C "$dir" rev-parse HEAD)"
  after="$(git -C "$dir" rev-parse "origin/$BRANCH")"
  [ "$before" = "$after" ] && return 0
  git -C "$dir" reset -q --hard "origin/$BRANCH"
  log "$dir: ${before:0:7} -> ${after:0:7}"
  echo changed
}

# Update this repo first. If the script itself changed, start the new copy.
if [ -z "${NAS_DEPLOY_REEXEC:-}" ] && [ -d "$HERE/.git" ]; then
  if [ "$(sync_repo "$HERE")" = changed ]; then
    NAS_DEPLOY_REEXEC=1 exec "${BASH_SOURCE[0]}" "$@"
  fi
fi

for app in $APPS; do
  case "$app" in
    /*) dir="$app" ;;
    *)  dir="$APPS_ROOT/$app" ;;
  esac
  if [ ! -d "$dir/.git" ]; then
    log "$dir: not a git clone, skipped"
    continue
  fi
  [ "$(sync_repo "$dir")" = changed ] || continue

  # An app that is not a Docker stack ships its own on-deploy.sh.
  if [ -x "$dir/on-deploy.sh" ]; then
    if (cd "$dir" && ./on-deploy.sh >> "$LOG_FILE" 2>&1); then
      log "$dir: on-deploy.sh done"
    else
      log "$dir: on-deploy.sh FAILED, see lines above"
    fi
    continue
  fi

  compose=""
  for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    [ -f "$dir/$f" ] && { compose="$f"; break; }
  done
  [ -n "$compose" ] || { log "$dir: no compose file and no on-deploy.sh, nothing restarted"; continue; }

  if (cd "$dir" && $DOCKER compose -f "$compose" up -d --build >> "$LOG_FILE" 2>&1); then
    log "$dir: compose up done"
  else
    log "$dir: compose up FAILED, see lines above"
  fi
done
