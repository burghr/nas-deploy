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
cd /home/bryant
git clone https://github.com/burghr/nas-deploy.git
cd nas-deploy
cp .env.example .env    # edit the APPS list
./install.sh            # adds the cron entry, every 5 minutes
```

To use a different interval, pass a cron schedule:

```bash
./install.sh "*/2 * * * *"
```

## Add an app

1. Make sure the folder on the NAS is a git clone of the GitHub repo.
2. Add the folder name to `APPS` in `.env`.

Nothing else is needed. The next run picks it up.

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
tail -n 20 /home/bryant/nas-deploy/deploy.log
```
