# How to test

## Unit tests

```sh
swift test
```

Covers config-loader on valid and invalid fixtures (AS-01, AS-02) and the log formatter output (AS-17).

## Manual E2E

Build first:

```sh
swift build
```

When run from a terminal, macOS asks Calendar access on behalf of the terminal app (Terminal / iTerm / Ghostty).

### AS-03 — list calendars from Exchange and Google

1. In System Settings → Internet Accounts, add an Exchange and a Google account with Calendars enabled.
2. Run `.build/debug/calsyn calendars` and accept the Calendar access prompt.
3. Check there is one `msg=calendar` line per calendar of both accounts, and that `echo $?` prints `0`.

### AS-13 — Calendar access denied

1. In System Settings → Privacy & Security → Calendars, disable the terminal app.
2. Run `.build/debug/calsyn calendars`.
3. Check there is an ERROR line `msg="calendar access denied"` and that `echo $?` prints a value ≠ 0.
