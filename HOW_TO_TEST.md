# How to test

## Unit tests

```sh
swift test
```

Covers config-loader on valid and invalid fixtures (AS-01, AS-02), the log formatter output (AS-17) and the
reconciler on the in-memory fake store, including recurring, all-day, declined, free and tentative source events
(AS-04..AS-11, AS-18), the runner reloading the config at every reconcile (AS-15), and `install`/`uninstall` against
a temporary home and a fake `launchctl`: binary copy, plist paths and content, load and unload calls (AS-16), and
`calsyn config` against a temporary folder and a fake `open -t`: empty file and parent folders created, existing file
kept, `--config <path>` opened, exit code ≠ 0 when the file cannot be created or `open -t` fails (TASK-010), and
`calsyn cleanup`: only the jobs with `cleanup: true` delete, in their destinations and inside the window, the events
whose title starts with the prefix of one of their sources.

## Manual E2E

Build first:

```sh
swift build
```

When run from a terminal, macOS asks Calendar access on behalf of the terminal app (Terminal / iTerm / Ghostty).

### AS-03 — list calendars from Exchange and Google

1. In System Settings → Internet Accounts, add an Exchange and a Google account with Calendars enabled.
2. Run `.build/debug/calsyn calendars` and accept the Calendar access prompt.
3. Check there is one `msg=calendar` line with `id`, `account` and `title` per calendar of both accounts, and that
   `echo $?` prints `0`.

### AS-13 — Calendar access denied

1. In System Settings → Privacy & Security → Calendars, disable the terminal app.
2. Run `.build/debug/calsyn calendars`.
3. Check there is an ERROR line `msg="calendar access denied"` and that `echo $?` prints a value ≠ 0.

### AS-04, AS-05 — reconcile clones between Exchange and Google

`calsyn once` writes to real calendars. Use two empty test calendars so the counts below are exact.

1. In Calendar.app create a calendar `calsyn-test` in the Exchange account and one in the Google account.
2. Run `.build/debug/calsyn calendars` and copy the `id` of both `calsyn-test` rows into `~/calsyn-e2e.yaml`:

   ```yaml
   calendars:
     - id: "<Exchange account>/calsyn-test"
       clone_prefix: "[W]"
     - id: "<Google account>/calsyn-test"
       clone_prefix: "[H]"
   sync:
     - name: work-to-home
       sources:
         - "<Exchange account>/calsyn-test"
       destinations:
         - "<Google account>/calsyn-test"
   ```

3. In Calendar.app add to the Exchange `calsyn-test` an event "Budget" tomorrow 10:00-11:00, with notes `Q4 numbers`.
4. Run `.build/debug/calsyn once --config ~/calsyn-e2e.yaml`.
5. AS-04: check stdout shows `msg="job reconciled" job=work-to-home created=1 deleted=0`, `echo $?` prints `0`, and
   the Google `calsyn-test` shows an event `[W]` tomorrow 10:00-11:00 with no notes.
6. Run step 4 again and check it logs `created=0 deleted=0`.
7. Add to the job:

   ```yaml
       details:
         title: true
         description: true
   ```

8. Run step 4 and check it logs `created=1 deleted=1`.
9. AS-05: wait for Calendar.app to sync, then check the Google `calsyn-test` shows only `[W] Budget` tomorrow
   10:00-11:00 with the notes `Q4 numbers`.
10. Run step 4 again and check it logs `created=0 deleted=0`. A `created=1 deleted=1` on every run means the server
    rewrote the clone notes (OP-03): report it.
11. Cleanup: delete "Budget", run step 4 (it logs `created=0 deleted=1`), then delete both `calsyn-test` calendars.

### AS-09 — recurring event cloned as standalone events

Run it on a weekday, so the series starts on one of its own days and the default window (today → +7 days) holds
exactly 5 occurrences.

1. Create the two `calsyn-test` calendars and `~/calsyn-e2e.yaml` as in steps 1-2 of AS-04, AS-05.
2. In Calendar.app add to the Exchange `calsyn-test` an event "Standup" today 09:00-09:15 that repeats weekly on
   Monday to Friday (Repeat → Custom…).
3. Run `.build/debug/calsyn once --config ~/calsyn-e2e.yaml`.
4. Check stdout shows `msg="job reconciled" job=work-to-home created=5 deleted=0` and that the Google `calsyn-test`
   shows one `[W]` event 09:00-09:15 on each weekday of the next 7 days and none after.
5. Open one of the `[W]` events and check it has no repeat rule.
6. Run step 3 again and check it logs `created=0 deleted=0`.
7. Cleanup: delete the "Standup" series (all events), run step 3 (it logs `created=0 deleted=5`), then delete both
   `calsyn-test` calendars.

### AS-14 — resident run `calsyn run`

`calsyn run` reconciles at startup, after every calendar store change and every 5 minutes. Each reconcile starts with
a `msg="settings loaded"` line followed by one `msg="job reconciled"` line per job. A reconcile that wrote clones is
usually followed by one more reconcile logging `created=0 deleted=0`: its own writes notify a store change.

1. Create the two `calsyn-test` calendars and `~/calsyn-e2e.yaml` as in steps 1-2 of AS-04, AS-05.
2. In Calendar.app add to the Exchange `calsyn-test` an event "Budget" tomorrow 10:00-11:00.
3. In a terminal run `.build/debug/calsyn run --config ~/calsyn-e2e.yaml` and leave it running.
4. Startup: check stdout shows `msg="settings loaded" calendars=2 sync_jobs=1` and
   `msg="job reconciled" job=work-to-home created=1 deleted=0`, and that the process keeps running.
5. Store change: in Calendar.app move "Budget" to 14:00-15:00. Without typing any command, check stdout shows a new
   `msg="settings loaded"` and `msg="job reconciled" job=work-to-home created=1 deleted=1` within a few seconds, and
   that the Google `calsyn-test` shows `[W]` only at 14:00-15:00.
6. Periodic: touch nothing for 11 minutes and check stdout shows a `settings loaded` + `job reconciled ...
   created=0 deleted=0` pair every 5 minutes (compare the `time=` fields).
7. No overlap: check that in the whole output every `msg="settings loaded"` line comes after the `job reconciled`
   lines of the previous reconcile; with one job, the two messages always alternate.
8. Config reload (AS-15): while `calsyn run` keeps running, add this job to `~/calsyn-e2e.yaml`:

   ```yaml
     - name: home-to-work
       sources:
         - "<Google account>/calsyn-test"
       destinations:
         - "<Exchange account>/calsyn-test"
   ```

   Move "Budget" back to 10:00-11:00 (or wait up to 5 minutes) and check the next reconcile logs `sync_jobs=2` and a
   `msg="job reconciled" job=home-to-work` line.
9. `created=1 deleted=1` lines repeating without any edit mean the server rewrites the clones (OP-03): report it.
10. Cleanup: stop `calsyn run` with Ctrl-C, delete "Budget", run `.build/debug/calsyn once --config ~/calsyn-e2e.yaml`
    (it logs `deleted=1` for `work-to-home`), then delete both `calsyn-test` calendars.

### AS-16 — LaunchAgent `calsyn install` / `calsyn uninstall`

The agent runs `~/.calsyn/bin/calsyn run` with the default config `~/.config/calsyn/config.yaml` and writes its
output to `~/Library/Logs/calsyn.log`.

1. Run `.build/debug/calsyn once` and check it logs `msg="settings loaded"` and that `echo $?` prints `0`.
2. Run `.build/debug/calsyn install` and check stdout shows `msg="agent installed"` and that `echo $?` prints `0`.
3. If macOS asks Calendar access, allow it.
4. Check `ls -l ~/.calsyn/bin/calsyn` shows the binary and `cat ~/Library/LaunchAgents/com.totomz.calsyn.plist`
   shows `ProgramArguments` `<home>/.calsyn/bin/calsyn` `run`, `RunAtLoad` and `KeepAlive` `true`,
   `ThrottleInterval` `300`.
5. Check `launchctl list | grep com.totomz.calsyn` prints one line whose first column is a PID (not `-`).
6. Run `tail -f ~/Library/Logs/calsyn.log` and check it shows `msg="settings loaded"` and one `msg="job reconciled"`
   line per job, then a new pair every 5 minutes (compare the `time=` fields). Stop it with Ctrl-C.
   `msg="calendar access denied"` repeating every 5 minutes means the agent has no Calendar access: launchd
   restarts it at most once every 300 s (`ThrottleInterval`). Report it.
7. Log out of macOS, log in again, then check `launchctl list | grep com.totomz.calsyn` prints a PID again and
   `~/Library/Logs/calsyn.log` shows a new `msg="settings loaded"` line with a `time=` after the login.
8. Reinstall: run `.build/debug/calsyn install` again, check it logs `msg="agent installed"` and that
   `launchctl list | grep com.totomz.calsyn` prints a new PID.
9. Run `.build/debug/calsyn install --config ~/calsyn-e2e.yaml` and check it logs
   `level=ERROR msg="unknown argument" argument=--config`, that `echo $?` prints a value ≠ 0 and that
   `launchctl list | grep com.totomz.calsyn` still prints the PID of step 8.
10. Run `.build/debug/calsyn uninstall` and check stdout shows `msg="agent uninstalled"` and that `echo $?` prints `0`.
11. Check `launchctl list | grep com.totomz.calsyn` prints nothing and
    `ls ~/Library/LaunchAgents/com.totomz.calsyn.plist` reports `No such file or directory`.
12. Cleanup: `uninstall` leaves the binary and the log in place; remove them with `rm -rf ~/.calsyn` and
    `rm ~/Library/Logs/calsyn.log`.

### TASK-010 — open the config with `calsyn config`

`calsyn config` opens the file with `open -t`, in the macOS default text editor (TextEdit unless changed). The failure
of `open -t` (ERROR line naming the path, exit code ≠ 0) is covered by `swift test`.

1. Existing config: check `~/.config/calsyn/config.yaml` exists, run `.build/debug/calsyn config` and check the file
   opens in the default text editor with its content, stdout shows `msg="config opened"` with
   `path=<home>/.config/calsyn/config.yaml`, and `echo $?` prints `0`. Close the editor without saving.
2. Missing config: move the folder aside with `mv ~/.config/calsyn ~/.config/calsyn.bak`, run
   `.build/debug/calsyn config` and check an empty document opens in the default text editor, stdout shows
   `msg="config opened"`, `echo $?` prints `0`, and `wc -c ~/.config/calsyn/config.yaml` prints `0`. Close the
   editor without saving.
3. Restore the config: `rm -rf ~/.config/calsyn && mv ~/.config/calsyn.bak ~/.config/calsyn`.
4. `--config <path>`: run `.build/debug/calsyn config --config ~/calsyn-e2e/config.yaml` and check an empty document
   opens in the default text editor, stdout shows `msg="config opened" path=<home>/calsyn-e2e/config.yaml`,
   `echo $?` prints `0`, and `ls ~/calsyn-e2e/config.yaml` lists the file. Close the editor without saving.
5. Cleanup: `rm -rf ~/calsyn-e2e`.
