#!/usr/bin/env python3
"""
calsyn - Outlook synchronization via outlook-cli (https://github.com/yusufaltunbicak/outlook-cli)

Usage: calsync.py <account[,account...]> <repo-url> [repo-path]
  accounts   comma-separated list of outlook-cli account profiles to sync,
             one at a time (each must match a calendar `profile` with
             type=outlook in settings.json)
  repo-url   git URL of the calsyn repository
  repo-path  local path of the clone; defaults to ~/.calsync/<repo-name>.
             Cloned on the first run, pulled on the following ones.

Run by cron every 5 minutes. For each account:
1. overwrites <profile>-events.json with the calendar events (clones excluded)
2. for every sync job where the calendar is a destination, reconciles the
   clone events against the <source.profile>-events.json files

Only the python standard library is required. See README.md for the full
architecture.
"""

import json
import hashlib
import logging
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

WINDOW_DAYS = 14

logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
log = logging.getLogger("calsync")


def normalize(value):
    return (value or "").replace("\r\n", "\n").strip()


def short_date(value):
    """'2026-07-13T13:00:00+00:00' -> '2026-07-13 13:00' (already UTC)"""
    return value[0:16].replace("T", " ")


def utc_to_local(value):
    """'YYYY-MM-DD HH:MM' UTC -> local 'YYYY-MM-DDTHH:MM', the format expected by event-create"""
    utc = datetime.strptime(value, "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc)
    return utc.astimezone().strftime("%Y-%m-%dT%H:%M")


def event_hash(title, from_, to, description):
    """sha1 identity of a clone, computed on the cloned fields only (see README.md -> 'Hash')"""
    payload = f"{title}|{from_}|{to}|{description}"
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def plain_description(event):
    """Plain-text description of an outlook-cli event: clones are created with
    a text body, original events are usually HTML so the plain preview is used"""
    body = event.get("body") if event.get("body_type") == "Text" else event.get("body_preview")
    return normalize(body)


def run(args, cwd=None):
    result = subprocess.run(
        args, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True
    )
    if result.returncode != 0:
        log.error(
            'command failed: cmd="%s" stdout="%s" stderr="%s"',
            " ".join(args), result.stdout.strip()[:500], result.stderr.strip()[:500],
        )
        raise RuntimeError(f"command failed: {' '.join(args)}")
    return result.stdout


def outlook_cmd(args, account, retries=1):
    """Runs an outlook-cli command and returns its stdout. Failed commands are
    retried once: Exchange occasionally rejects a call transiently (throttling,
    session refresh) and the same command succeeds right after"""
    try:
        return run(["outlook", *args, "--account", account])
    except RuntimeError:
        if retries <= 0:
            raise
        log.info("retrying outlook command: account=%s", account)
        time.sleep(5)
        return outlook_cmd(args, account, retries - 1)


def outlook_json(args, account):
    """Runs an outlook-cli command with --json and returns the `data` payload,
    validating the response envelope (event-delete does not support --json,
    use outlook_cmd for it)"""
    stdout = outlook_cmd([*args, "--json"], account)
    try:
        envelope = json.loads(stdout)
    except json.JSONDecodeError as e:
        log.error('outlook returned invalid json: account=%s output="%s"', account, stdout[:200])
        raise RuntimeError(f"invalid json from outlook for account {account}") from e

    if not envelope.get("ok"):
        log.error('outlook returned an error: account=%s response="%s"', account, stdout[:200])
        raise RuntimeError(f"outlook error for account {account}")
    return envelope.get("data", [])


def git(repo_dir, *args):
    return run(["git", "-C", str(repo_dir), *args])


def load_settings(repo_dir):
    """Loads and validates settings.json: every calendar must have a non-empty
    name and event_clone_prefix (an empty prefix would match every event via
    startswith('') and delete most of the calendar)"""
    settings_file = repo_dir / "settings.json"
    if not settings_file.is_file():
        raise RuntimeError(f"settings.json not found in {repo_dir}")

    settings = json.loads(settings_file.read_text())
    invalid = [
        c.get("profile", "?")
        for c in settings["calendars"]
        if not str(c.get("event_clone_prefix", "")).strip() or not str(c.get("name", "")).strip()
    ]
    if invalid:
        raise RuntimeError(f"calendars with empty name or event_clone_prefix: {invalid}")
    return settings


def find_calendar(settings, **fields):
    for calendar in settings["calendars"]:
        if all(calendar.get(key) == value for key, value in fields.items()):
            return calendar
    return None


def sync_source(account, job, source, calendar_events, repo_dir, w_start, w_end):
    """Reconciles the clones of a single source into the account calendar.

    The wanted state is the source events file reduced to the fields listed in
    job.details and identified by their hash; existing clones matching a wanted
    hash are kept (multiset semantics, duplicated events are preserved), the
    others are deleted, unmatched wanted events are created."""
    prefix = source["event_clone_prefix"]
    details = job.get("details") or []
    events_file = repo_dir / f"{source['profile']}-events.json"
    if not events_file.is_file():
        log.info('source events file not found, skipping: job="%s" source=%s', job["job"], source["name"])
        return

    wanted = [
        {
            "title": normalize(e["title"]) if "title" in details else "",
            "from": e["from"],
            "to": e["to"],
            "description": normalize(e["description"]) if "description" in details else "",
        }
        for e in json.loads(events_file.read_text())
        if w_start <= e["from"] <= w_end
    ]
    wanted_hashes = [event_hash(e["title"], e["from"], e["to"], e["description"]) for e in wanted]

    to_delete = []
    for clone in (e for e in calendar_events if e["subject"].startswith(prefix)):
        hash_ = event_hash(
            normalize(clone["subject"][len(prefix):]),
            short_date(clone["start"]),
            short_date(clone["end"]),
            plain_description(clone),
        )
        if hash_ in wanted_hashes:
            index = wanted_hashes.index(hash_)
            del wanted_hashes[index]
            del wanted[index]
        else:
            to_delete.append(clone["id"])

    if to_delete:
        outlook_cmd(["event-delete", *to_delete, "-y"], account)

    for event in wanted:
        title = f"{prefix} {event['title']}" if event["title"] else prefix
        outlook_json(
            [
                "event-create",
                title,
                utc_to_local(event["from"]),
                utc_to_local(event["to"]),
                "-b",
                event["description"],
                "-y",
            ],
            account,
        )

    log.info(
        'source synced: job="%s" source=%s created=%d deleted=%d',
        job["job"], source["name"], len(wanted), len(to_delete),
    )


def sync_account(account, settings, repo_dir, w_start, w_end):
    """Exports the account events to <account>-events.json, then reconciles
    every sync job where the account calendar is a destination"""
    me = find_calendar(settings, type="outlook", profile=account)
    if me is None:
        log.error("no outlook calendar with profile '%s' in settings.json, skipping", account)
        return

    prefixes = [c["event_clone_prefix"] for c in settings["calendars"]]
    calendar_events = outlook_json(
        ["calendar", "--days", str(WINDOW_DAYS), "--timezone", "UTC"], account
    )

    exported = [
        {
            "title": normalize(e["subject"]),
            "from": short_date(e["start"]),
            "to": short_date(e["end"]),
            "description": plain_description(e),
        }
        for e in calendar_events
        if not any(e["subject"].startswith(p) for p in prefixes)
    ]
    events_file = repo_dir / f"{account}-events.json"
    events_file.write_text(json.dumps(exported, indent=2, ensure_ascii=False) + "\n")
    log.info("events exported: profile=%s count=%d", account, len(exported))

    for job in settings["sync"]:
        if me["name"] not in job["destinations"]:
            continue
        for source_name in job["sources"]:
            source = find_calendar(settings, name=source_name)
            if source is None:
                log.error('source calendar not found in settings: job="%s" source=%s', job["job"], source_name)
                continue
            sync_source(account, job, source, calendar_events, repo_dir, w_start, w_end)


def main(argv):
    if len(argv) < 3 or len(argv) > 4:
        log.error("usage: %s <account[,account...]> <repo-url> [repo-path]", Path(argv[0]).name)
        return 1

    accounts = [a for a in argv[1].split(",") if a]
    repo_url = argv[2]
    repo_name = Path(repo_url.removesuffix(".git")).name
    repo_dir = Path(argv[3]) if len(argv) == 4 else Path.home() / ".calsync" / repo_name
    lock_dir = repo_dir.parent / f"{repo_dir.name}.lock"

    # The lock lives next to the clone, not inside it, so it survives the
    # initial clone and prevents overlapping cron runs
    repo_dir.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock_dir.mkdir()
    except FileExistsError:
        log.info("another synchronization is running, skipping")
        return 0

    try:
        if not (repo_dir / ".git").is_dir():
            log.info("cloning %s into %s", repo_url, repo_dir)
            run(["git", "clone", "--quiet", repo_url, str(repo_dir)])
        else:
            # Discard uncommitted leftovers of a previously crashed run
            # (a dirty tree would make pull --rebase fail), then update
            git(repo_dir, "reset", "--hard", "--quiet")
            git(repo_dir, "pull", "--rebase", "--quiet")

        settings = load_settings(repo_dir)
        now = datetime.now(timezone.utc)
        w_start = now.strftime("%Y-%m-%d") + " 00:00"
        w_end = (now + timedelta(days=WINDOW_DAYS)).strftime("%Y-%m-%d %H:%M")

        # A failing account does not stop the others; its export (if any)
        # is still committed and the run exits non-zero at the end
        failed = []
        for account in accounts:
            try:
                sync_account(account, settings, repo_dir, w_start, w_end)
            except RuntimeError as e:
                log.error("account sync failed: account=%s error=%s", account, e)
                failed.append(account)

        # Commit and push the exported files, if anything changed;
        # on a rejected push (concurrent writer) rebase and retry once
        for account in accounts:
            if (repo_dir / f"{account}-events.json").is_file():
                git(repo_dir, "add", "--", f"{account}-events.json")
        if subprocess.run(
            ["git", "-C", str(repo_dir), "diff", "--cached", "--quiet"], stdin=subprocess.DEVNULL
        ).returncode == 0:
            log.info("no changes to push")
            return 1 if failed else 0

        git(repo_dir, "commit", "--quiet", "-m", "calsyn: update events")
        try:
            git(repo_dir, "push", "--quiet")
        except RuntimeError:
            git(repo_dir, "pull", "--rebase", "--quiet")
            git(repo_dir, "push", "--quiet")
        log.info("events pushed")
        return 1 if failed else 0
    finally:
        lock_dir.rmdir()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
