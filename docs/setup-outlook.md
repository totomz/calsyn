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

## Mac OSX
`cron` on macOS runs outside your graphical session, so it cannot open the Chrome UI that outlook-cli needs when the OAuth token has to be refreshed interactively. Use a **LaunchAgent** instead: it runs inside your logged-in Aqua session and can show Chrome.

Create `~/Library/LaunchAgents/com.totomz.calsync.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.totomz.calsync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/Users/totomz/bin/calsync.py</string>
        <string>infocert,luxottica</string>
        <string>git@github.com:&lt;you&gt;/&lt;your-repo&gt;.git</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
</dict>
</plist>
```

Load it (runs immediately and then every `StartInterval` seconds):
```shell
launchctl load ~/Library/LaunchAgents/com.totomz.calsync.plist
```

Unload it to stop:
```shell
launchctl unload ~/Library/LaunchAgents/com.totomz.calsync.plist
```

Notes:
* `StartInterval` is in seconds (300 = every 5 minutes); use `StartCalendarInterval` for fixed times instead.
* The script logs to `calsync.py.log` next to `calsync.py`, so you do not need to redirect stdout here.
* You must be logged in (session unlocked) for the Chrome UI to appear when the token needs an interactive refresh.
