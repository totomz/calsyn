# Setup Otlook-cli

We use the great [outlook-cli](https://github.com/yusufaltunbicak/outlook-cli) to sync Outlook calendars

The setup is as easy as:
```shell
uv tool install --force --python 3.13 outlook365-cli
uvx --from outlook365-cli playwright install chromium
```

Now, for each outlook account, run:
```shell
outlook account add infocert
```

## Setup calsync.py
`calsync.py` reads and creates the clone events using outlook-cli, and keeps a local clone of the GitHub repository to exchange the events files with the other calendars.

Requirements: `python3` (no external libraries), `git` (with credentials for the private repository).

Download [calsync.py](../calsync.py) somewhere **outside** the repository, make it executable, and schedule it with cron every 5 minutes:

```shell
chmod +x ~/bin/calsync.py
crontab -e
```

```
*/5 * * * * ~/bin/calsync.py infocert,luxottica git@github.com:<you>/<your-repo>.git >> ~/.calsync/calsync.log 2>&1
```

Arguments:
* `accounts`: comma-separated list of the outlook-cli profiles to sync; each one must match the `profile` of a `type=outlook` calendar in `settings.json`;
* `repo-url`: git URL of your private repository;
* `repo-path` (optional): local path of the clone, defaults to `~/.calsync/<repo-name>`. The script clones the repository on the first run and pulls it on the following ones.

That's it
