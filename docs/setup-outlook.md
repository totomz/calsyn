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

That's it