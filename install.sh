#!/usr/bin/env bash
# Add the cron entry for deploy.sh. Safe to run more than once.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEDULE="${1:-*/5 * * * *}"
LINE="$SCHEDULE $HERE/deploy.sh"

[ -f "$HERE/.env" ] || { echo "create $HERE/.env first, see .env.example" >&2; exit 1; }

current="$(crontab -l 2>/dev/null || true)"
without="$(printf '%s\n' "$current" | grep -v "$HERE/deploy.sh" || true)"
printf '%s\n%s\n' "$without" "$LINE" | sed '/^$/d' | crontab -
echo "installed: $LINE"
crontab -l
