#!/usr/bin/env bash
# Install the cron entry for deploy.sh in /etc/cron.d. Safe to run more than once.
#
# The entry goes in /etc/cron.d, not in the user crontab: on OpenMediaVault,
# folder2ram keeps /var/spool (the user crontabs) in RAM, so a reboot can lose
# a "crontab -e" entry. Files in /etc/cron.d are on disk. Needs sudo.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEDULE="${1:-*/5 * * * *}"
RUN_AS="$(id -un)"
CRON_FILE=/etc/cron.d/nas-deploy

[ -f "$HERE/.env" ] || { echo "create $HERE/.env first, see .env.example" >&2; exit 1; }

sudo tee "$CRON_FILE" >/dev/null <<EOF
# Run nas-deploy every few minutes. Installed by $HERE/install.sh.
# Lives in /etc/cron.d because OMV folder2ram keeps /var/spool (user crontabs) in RAM.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=""
$SCHEDULE $RUN_AS $HERE/deploy.sh
EOF
sudo chown root:root "$CRON_FILE"
sudo chmod 644 "$CRON_FILE"

# Remove an old entry from the user crontab, if one is left.
if crontab -l 2>/dev/null | grep -q "$HERE/deploy.sh"; then
  crontab -l | grep -v "$HERE/deploy.sh" | crontab -
  echo "removed the old entry from the user crontab"
fi

echo "installed $CRON_FILE:"
cat "$CRON_FILE"
