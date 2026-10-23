# How to test

## Unit tests

```sh
swift test
```

Covers config-loader on valid and invalid fixtures (AS-01, AS-02), the log formatter output (AS-17) and the
reconciler on the in-memory fake store (AS-04..AS-08, AS-11, AS-18).

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
