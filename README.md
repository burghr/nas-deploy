# nas-deploy

Keep the app folders on the NAS equal to their GitHub branch.

Cron runs `deploy.sh` every five minutes. For each folder in the list, the
script fetches the branch from GitHub. If the folder is behind, the script
resets the folder to the branch and runs `docker compose up -d --build`.
If the folder already matches, the script does nothing.

The script updates its own folder first. When `deploy.sh` changes, the new
copy starts at once.

## Setup on the NAS

```bash
cd ~
git clone https://github.com/burghr/nas-deploy.git
cd nas-deploy
cp .env.example .env    # edit the APPS list
./install.sh            # writes /etc/cron.d/nas-deploy, every 5 minutes (needs sudo)
```

`install.sh` writes the cron entry to `/etc/cron.d/nas-deploy`, not to the
user crontab. On OpenMediaVault, folder2ram keeps the user crontabs in RAM, so
a reboot can lose them. `deploy.sh` writes to the log only when an app changes,
so a quiet log does not prove that cron runs. To check, read the cron journal:
`sudo journalctl -u cron | grep nas-deploy`.

To use a different interval, pass a cron schedule:

```bash
./install.sh "*/2 * * * *"
```

## Add an app

1. Make sure the folder on the NAS is a git clone of the GitHub repo.
2. Add the folder name to `APPS` in `.env`.

Nothing else is needed. The next run picks it up.

## Apps that are not Docker stacks

Put an executable `on-deploy.sh` in the root of the app repo. When the
folder changes, `deploy.sh` runs that script instead of `docker compose`.
The script runs inside the app folder. For example, a systemd service:

```bash
#!/usr/bin/env bash
set -euo pipefail
.venv/bin/pip install -q -r requirements.txt
sudo -n systemctl restart my-service
```

## Rules

- The script uses `git reset --hard`. A hand edit to a tracked file on the
  NAS is lost at the next run. Edit on the Mac, push, and wait.
- Files that git does not track are safe. That includes `.env`, `data/`,
  and any other ignored file.
- The script rebuilds a container only when the folder changed. A pull
  alone never restarts anything.

## Log

Each run appends to `deploy.log` in this folder. A run with no change
writes nothing. Check the last lines with:

```bash
tail -n 20 ~/nas-deploy/deploy.log
```
