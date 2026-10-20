# EP-001 — Calendar sync through Calendar.app — Analysis

## Index
1. [Requirement](#1-requirement)
2. [Folding rules](#2-folding-rules)
3. [Scope](#3-scope)
4. [Actor / role](#4-actor--role)
5. [Capabilities](#5-capabilities)
6. [Journey delta (CLI surfaces)](#6-journey-delta-cli-surfaces)
7. [Orchestration delta](#7-orchestration-delta)
8. [Container / component impact](#8-container--component-impact)
9. [Data delta](#9-data-delta)
10. [External systems](#10-external-systems)
11. [Non-functional](#11-non-functional)
12. [Acceptance statements](#12-acceptance-statements)
13. [Verification rows](#13-verification-rows)
14. [Decisions Needed](#14-decisions-needed)
15. [Assumptions](#15-assumptions)
16. [Open Points](#16-open-points)
17. [Grill log](#17-grill-log)
18. [Coverage ledger](#18-coverage-ledger)

## 1. Requirement

| ID | Definition | Provenance | Status |
|---|---|---|---|
| R-01 | "Dobbiamo implementare un sistema che sincronizzi piu' calendari sfruttando osx Calendar.App. Calendar.app ha gia tutta l'integrazione per autenticarsi su outlook, gmail e sarkazzi. Le specifiche di partenza sono nel README.md" | user prompt | Verbatim |
| R-02 | "Non esiste as-sis perchè è un progetto nuovo" | user prompt | Verbatim |
| R-03 | Clones exist so that others see availability, changes reach every client, and notifications work | `README.md:3-6` | Source |

## 2. Folding rules

| ID | Definition | Provenance | Status |
|---|---|---|---|
| F-01 | One capability = one observable effect on a calendar, or one operator action (configure, list, run, install) | spec-writer phase 1 | Published |
| F-02 | Create and delete of clones inside a job fold into one capability (reconcile) | spec-writer phase 1 | Published |
| F-03 | The `details` fields, event filters and time window fold into reconcile; they are not separate capabilities | spec-writer phase 1 | Published |
| F-04 | Two commands that trigger the same reconcile are separate capabilities only if their trigger differs (`run` vs `once`) | spec-writer phase 1 | Published |
| F-05 | Logging is a non-functional row, not a capability | spec-writer phase 1 | Published |

## 3. Scope

| ID | Definition | Provenance | Status |
|---|---|---|---|
| S-01 | IN: one-way clone jobs `source → destinations[]` between calendars visible in Calendar.app | `README.md:37-58` | Settled |
| S-02 | IN: Swift binary using EventKit; no credentials handled by calsyn | G1-Q1 | Settled |
| S-03 | IN: YAML config, commands `run`, `once`, `calendars`, `install`, `uninstall` | G1-Q2, G4-Q3 | Settled |
| S-04 | OUT: per-event `color` (EventKit has color per calendar only) | G1-Q4 | Excluded |
| S-05 | OUT: README / FAQ updates | G5-Q2 | Excluded |
| S-06 | OUT: copying alarms, availability, location | G4-Q2 | Excluded |
| S-07 | OUT: validation of duplicate prefixes ("amen, si duplicano") | G3-Q1 | Excluded |
| S-08 | OUT: debounce of change notifications; clones are ignored as sources so the loop converges | G3-Q2 | Excluded |
| S-09 | OUT: Homebrew tap, signed/notarized release | G5-Q4 | Excluded |
| S-10 | OUT: event filters (every source event is cloned) | G2-Q4 | Excluded |

## 4. Actor / role

| ID | Definition | Provenance | Status |
|---|---|---|---|
| ACT-01 | **Operator**: the Mac owner who has Internet Accounts in Calendar.app, writes `config.yaml`, installs and runs calsyn | G6-Q2 ("a che cazzo ti serve?") | Assumption A-07 |
| ACT-02 | **Calendar viewer**: colleague who sees the clones in a destination calendar (no action on calsyn) | `README.md:4` | Derived |

## 5. Capabilities

| ID | Definition | Provenance | Status |
|---|---|---|---|
| C-01 | Load config: read `~/.config/calsyn/config.yaml` (or `--config <path>`), validate it, reload it on every reconcile | G3-Q3 | Settled |
| C-02 | List calendars: `calsyn calendars` prints account + title of each calendar EventKit can see | G2-Q2, G4-Q3 | Settled |
| C-03 | Reconcile: for each job, compute the wanted clones per destination, delete the extra clones, create the missing ones | `README.md:37-58`, G1-Q3, G2-Q1 | Settled |
| C-04 | Resident run: `calsyn run` reconciles at startup, on every store-change notification and every 5 min | G2-Q3, G4-Q1 | Settled |
| C-05 | One-shot run: `calsyn once` reconciles once and exits | G4-Q3 | Settled |
| C-06 | Install / uninstall: `calsyn install` copies the binary to `~/.calsyn/bin`, writes and loads the LaunchAgent; `uninstall` unloads and removes it | G4-Q3, G5-Q4 | Settled |

Reconcile rules (part of C-03):

| ID | Definition | Provenance | Status |
|---|---|---|---|
| RC-01 | A source event is an event in the source calendar whose title starts with no configured `clone_prefix` | old `calsync.py` (HEAD), G3-Q2 | Settled |
| RC-02 | A clone of source S in destination D is an event in D whose title starts with `S.clone_prefix` | old `calsync.py` `sync_source` (HEAD) | Derived |
| RC-03 | Clone identity = prefix + start + end + all-day flag + cloned title (if `details.title`) + cloned description (if `details.description`) | G1-Q3, G3-Q1 | Settled |
| RC-04 | Any difference in identity → delete the old clone and create a new one (no in-place update); identical identities are matched as a multiset | G2-Q1 | Settled |
| RC-05 | Recurring occurrences become standalone, non-recurring clones | G2-Q4, `docs/faq.md` | Settled |
| RC-06 | All-day, declined, free and tentative events are cloned | G2-Q4 | Settled |
| RC-07 | The clone carries start, end, all-day flag; title `<prefix>` or `<prefix> <title>`; notes = description only if `details.description` | G4-Q2, A-04 | Settled |
| RC-08 | Only events inside the window are read or touched; default start of today −0 days → +7 days, configurable | G6-Q1 | Settled |
| RC-09 | Clones in D already created by the old system are treated like any other clone | G5-Q1 | Settled |

## 6. Journey delta (CLI surfaces)

| ID | Definition | Provenance | Status |
|---|---|---|---|
| J-01 | `calsyn calendars` → stdout table account/title | C-02 | New |
| J-02 | `calsyn once [--config p]` → logs on stdout/log file, exit code | C-05 | New |
| J-03 | `calsyn run [--config p]` → resident process, logs | C-04 | New |
| J-04 | `calsyn install` / `calsyn uninstall` → LaunchAgent state | C-06 | New |

```
Operator
  │ 1. adds accounts in System Settings → Internet Accounts (outside calsyn)
  │ 2. runs `calsyn calendars`        → copies account/title into config.yaml
  │ 3. runs `calsyn once`             → grants Calendar access (TCC), checks the log
  │ 4. runs `calsyn install`          → LaunchAgent starts `calsyn run`
  ▼
Calendar viewer sees clones in the destination calendars
```

## 7. Orchestration delta

| ID | Definition | Provenance | Status |
|---|---|---|---|
| O-01 | LaunchAgent (user session, RunAtLoad, KeepAlive) runs `~/.calsyn/bin/calsyn run` | G2-Q3, G5-Q4, old `com.totomz.calsync.plist` | New |
| O-02 | Reconcile triggers: startup, EventKit store-changed notification, 5 min timer | G4-Q1 | New |
| O-03 | Reconciles are serialised: one at a time inside the process | C-04 | Derived |

```
launchd ──start──▶ calsyn run ──┬─ startup ─────────────┐
                                ├─ EKEventStoreChanged ─┼─▶ reconcile ─▶ EventKit store ─▶ Calendar.app sync ─▶ Exchange/Google/...
                                └─ timer 300 s ─────────┘        ▲
                                     config.yaml (reloaded) ─────┘
```

## 8. Container / component impact

| ID | Definition | Provenance | Status |
|---|---|---|---|
| CT-01 | Repo `calsyn` (this git repo), new Swift Package | git | New |
| CT-02 | Container `calsyn-cli`: Swift executable | G1-Q1 | Proposed |
| CP-01 | `config-loader`: YAML parse + validation (Yams) | C-01, A-06 | Proposed |
| CP-02 | `calendar-store`: protocol over EventKit, plus an in-memory fake for tests | C-02, C-03, G4-Q4 | Proposed |
| CP-03 | `reconciler`: pure logic RC-01..RC-09 | C-03 | Proposed |
| CP-04 | `runner`: triggers O-02, serialisation O-03 | C-04, C-05 | Proposed |
| CP-05 | `launch-agent`: plist write/remove, `launchctl` load/unload | C-06 | Proposed |
| CP-06 | `cli`: argument parsing, subcommands J-01..J-04 | §6 | Proposed |
| CT-03 | Legacy `calsync.py`, `google-sync.gs`, `osx-setup.sh`, plist: already staged as deleted | git status | Removed |

## 9. Data delta

| ID | Definition | Provenance | Status |
|---|---|---|---|
| D-01 | `config.yaml` at `~/.config/calsyn/config.yaml` | G3-Q3 | New |
| D-02 | `calendars[].name`: key used by jobs | `README.md:20-31` | Settled |
| D-03 | `calendars[].account`: Calendar.app account title | G2-Q2 | New |
| D-04 | `calendars[].title`: calendar title inside the account | G2-Q2 | New |
| D-05 | `calendars[].clone_prefix`: non-empty, different per calendar (not validated) | `README.md:24`, G3-Q1 | Settled |
| D-06 | `sync[].name`, `sync[].source` (one), `sync[].destinations[]` | `README.md:37-50` | Settled |
| D-07 | `sync[].details.title`, `sync[].details.description` (bool, default false) | `README.md:47-58`, A-01 | Settled |
| D-08 | `window.past_days` (default 0), `window.future_days` (default 7) | G6-Q1, A-08 | New |
| D-09 | `settings.json`: superseded, left untouched and unused | A-03 | Superseded |
| D-10 | LaunchAgent plist `~/Library/LaunchAgents/com.totomz.calsyn.plist` | G5-Q4 | New |
| D-11 | Log file `~/Library/Logs/calsyn.log` (launchd stdout/stderr) | G5-Q4 | New |

## 10. External systems

| ID | Definition | Provenance | Status |
|---|---|---|---|
| X-01 | EventKit / Calendar store: read and write events | G1-Q1 | Integrated |
| X-02 | Calendar.app Internet Accounts: authentication and server sync, owned by macOS | R-01 | Precondition |
| X-03 | TCC Calendar full access: granted once to the binary | A-05 | Precondition |
| X-04 | launchd / `launchctl` | O-01 | Integrated |

## 11. Non-functional

| ID | Definition | Provenance | Status |
|---|---|---|---|
| N-01 | Latency from local store change to clone: `unbudgeted` | G5-Q3 | Settled |
| N-02 | Capacity (events/calendars): `unbudgeted` | G6-Q3 | Settled |
| N-03 | Logs in logfmt, INFO or ERROR only; one summary line per job: `created=N deleted=N` | CLAUDE.md, G5-Q4 | Settled |
| N-04 | No credentials stored or read by calsyn | `README.md:8-9` | Settled |
| N-05 | Minimum macOS version | OP-01 | Open |

## 12. Acceptance statements

| ID | Definition | Provenance | Status |
|---|---|---|---|
| AS-01 | The Operator runs `calsyn once` with a valid config → log `msg="settings loaded"` and exit code 0 | C-01 | Agreed |
| AS-02 | Config with a missing required field or a job referencing an unknown `name` → ERROR log naming the field, exit ≠ 0, no calendar written | C-01 | Agreed |
| AS-03 | The Operator runs `calsyn calendars` → one row per calendar showing account and title | C-02 | Agreed |
| AS-04 | Source event in the window, no clone yet → after `calsyn once` destination D shows an event `<prefix>` with the same start/end | RC-03, RC-07 | Agreed |
| AS-05 | `details.title`/`details.description` true → the clone shows `<prefix> <title>` and the source description | RC-07 | Agreed |
| AS-06 | Source event moved or a cloned field changed → after the reconcile D shows only the updated clone | RC-04 | Agreed |
| AS-07 | Source event deleted → after the reconcile its clone is gone from D | RC-04 | Agreed |
| AS-08 | Two jobs A→B and B→A: after two consecutive `calsyn once` runs, the second run logs `created=0 deleted=0` | RC-01 | Agreed |
| AS-09 | Recurring source event → D shows one standalone non-recurring clone per occurrence in the window | RC-05 | Agreed |
| AS-10 | All-day, declined, free, tentative source events → cloned; all-day stays all-day | RC-06, RC-07 | Agreed |
| AS-11 | Events and clones outside the window are neither created nor deleted; `window` overrides the 0/+7 default | RC-08 | Agreed |
| AS-12 | Job with a calendar not found in EventKit or a read-only destination → ERROR for that job, the other jobs are reconciled | G3-Q4 | Agreed |
| AS-13 | Calendar access denied → ERROR log, exit ≠ 0 | A-05 | Agreed |
| AS-14 | `calsyn run` reconciles at startup, after a store change, and every 5 min (visible as log lines) | C-04 | Agreed |
| AS-15 | Config edited while `calsyn run` is running → the next reconcile uses the new config without a restart | C-01 | Agreed |
| AS-16 | `calsyn install` → binary in `~/.calsyn/bin`, plist loaded, `~/Library/Logs/calsyn.log` growing; `calsyn uninstall` → plist unloaded and removed | C-06 | Agreed |
| AS-17 | Every log line is logfmt with level INFO or ERROR | N-03 | Agreed |
| AS-18 | Clones left by the old system that match a wanted identity stay; the others are deleted | RC-09 | Agreed |

## 13. Verification rows

| ID | Definition | Provenance | Status |
|---|---|---|---|
| V-01 | AS-01 — Unit: config-loader on a valid fixture | G4-Q4 | Planned |
| V-02 | AS-02 — Unit: config-loader on invalid fixtures; runner writes nothing | G4-Q4 | Planned |
| V-03 | AS-03 — Manual E2E: `calsyn calendars` on a Mac with Exchange + Google | G4-Q4 | Planned |
| V-04 | AS-04 — Unit: reconciler on the fake store | G4-Q4 | Planned |
| V-05 | AS-05 — Unit: reconciler with the `details` combinations | G4-Q4 | Planned |
| V-06 | AS-06 — Unit: reconciler, moved/retitled source | G4-Q4 | Planned |
| V-07 | AS-07 — Unit: reconciler, deleted source | G4-Q4 | Planned |
| V-08 | AS-08 — Unit: bidirectional jobs, second pass yields no changes | G4-Q4 | Planned |
| V-09 | AS-09 — Unit (fake occurrences) + Manual E2E on a real recurring event | G4-Q4 | Planned |
| V-10 | AS-10 — Unit: reconciler with all-day/declined/free/tentative fixtures | G4-Q4 | Planned |
| V-11 | AS-11 — Unit: window boundaries and override | G4-Q4 | Planned |
| V-12 | AS-12 — Unit: fake store with a missing or read-only calendar | G4-Q4 | Planned |
| V-13 | AS-13 — Manual E2E: TCC access revoked in System Settings | G4-Q4 | Planned |
| V-14 | AS-14 — Manual E2E: edit an event in Calendar.app, check the log | G4-Q4 | Planned |
| V-15 | AS-15 — Unit: runner reloads config at every reconcile | G4-Q4 | Planned |
| V-16 | AS-16 — Manual E2E: `calsyn install`, `launchctl list`, `calsyn uninstall` | G4-Q4 | Planned |
| V-17 | AS-17 — Unit: log formatter output | G4-Q4 | Planned |
| V-18 | AS-18 — Unit: fake store seeded with legacy clones | G4-Q4 | Planned |

## 14. Decisions Needed

| ID | Definition | Provenance | Status |
|---|---|---|---|
| DN-00 | None open: every grill question has a terminal answer | §17 | Closed |

## 15. Assumptions

| ID | Definition | Provenance | Status |
|---|---|---|---|
| A-01 | The `details` key is `description` (README typo `descrription`) | G6-Q4 | Confirmed |
| A-02 | Notifications on clones come from the destination calendar's default alerts | G6-Q4 | Confirmed |
| A-03 | `settings.json` is superseded by `config.yaml` and left unused | G6-Q4 | Confirmed |
| A-04 | Clone title = `<prefix>` or `<prefix> <title>` | G6-Q4 | Confirmed |
| A-05 | Calendar access denied → the process exits with ERROR | G6-Q4 | Confirmed |
| A-06 | YAML parsed via an SPM dependency (Yams) | G6-Q4 | Confirmed |
| A-07 | The actor is named "Operator" (the user declined to choose a persona) | G6-Q2 | Assumed |
| A-08 | The window lives at the top level of the config as `window.past_days` / `window.future_days` | G6-Q1 | Assumed |

## 16. Open Points

| ID | Definition | Provenance | Status |
|---|---|---|---|
| OP-01 | Minimum macOS version (the EventKit full-access API changed in macOS 14); affects task advisory only | §11 N-05 | Open — non-blocking |
| OP-02 | Clones left behind when a job is removed from the config are never cleaned | RC-02 | Open — non-blocking |
| OP-03 | Exchange/Google may rewrite the clone notes (HTML/text) → description mismatch → delete+recreate every cycle; checked in V-05 manual run | old `plain_description` (HEAD) | Open — non-blocking |

## 17. Grill log

| ID | Definition (round · question) | Provenance (answer verbatim) | Status (what it settled) |
|---|---|---|---|
| G1-Q1 | 1 · Runtime | "Swift + EventKit (Recommended)" | S-02, CT-02 |
| G1-Q2 | 1 · Config format | "README YAML" | D-01..D-07 |
| G1-Q3 | 1 · Clone identity | "prefix + stare&end time" | RC-03 |
| G1-Q4 | 1 · `color` | "Out of scope (Recommended)" | S-04 |
| G2-Q1 | 2 · Changes / same slot | "Delete + recreate on any difference" | RC-04 |
| G2-Q2 | 2 · Calendar identification | "Account + title (Recommended)" | D-03, D-04 |
| G2-Q3 | 2 · Trigger | "LaunchAgent + EventKit change notifications" | O-01, O-02 |
| G2-Q4 | 2 · Source filter | "Recurring as single (Recommended), Free/tentative, Declined events, All-day events" | RC-05, RC-06 |
| G3-Q1 | 3 · Duplicate prefixes | "il eereadme è sbagliato, i prefix sono diversi per calendario. Se hanno il summary, usi il summary. Altrimenti amen, si duplicano e si impicciano" | D-05, RC-03, S-07 |
| G3-Q2 | 3 · Self-notification | "lo script genera gli eventi con il prefix e IGNORA gli eventi con il prefix" | RC-01, S-08 |
| G3-Q3 | 3 · Config path | "~/.config/calsyn/config.yaml (Recommended)" | C-01, D-01 |
| G3-Q4 | 3 · Job failure | "Skip the job, continue (Recommended)" | AS-12 |
| G4-Q1 | 4 · Fallback | "Notifications + every 5 min (Recommended)" | O-02 |
| G4-Q2 | 4 · Clone attributes | "All-day flag" | RC-07, S-06 |
| G4-Q3 | 4 · CLI | "`calsyn run`, `calsyn calendars`, `calsyn install`/`uninstall`, `calsyn once`" | C-02, C-04..C-06 |
| G4-Q4 | 4 · Test levels | "Unit XCTest, fake store (Recommended), Manual E2E Exchange/Google" | §13 |
| G5-Q1 | 5 · Legacy clones | "Reconcile them normally (Recommended)" | RC-09 |
| G5-Q2 | 5 · Docs | "Out of scope" | S-05 |
| G5-Q3 | 5 · Latency | "Unbudgeted" | N-01 |
| G5-Q4 | 5 · Distribution / logs | "Source build + install (Recommended)" | C-06, D-10, D-11 |
| G6-Q1 | 6 · Window | "configurable, default -0 +7 gg" | RC-08, D-08 |
| G6-Q2 | 6 · Actor | "a che cazzo ti serve?" | A-07 |
| G6-Q3 | 6 · Capacity | "Unbudgeted (Recommended)" | N-02 |
| G6-Q4 | 6 · Assumptions A1-A6 | "Confirmed" | A-01..A-06 |

## 18. Coverage ledger

| ID | Definition (dimension) | Provenance | Status |
|---|---|---|---|
| L-01 | scope boundary | §3 | Answered |
| L-02 | actor/role | §4 | Assumed (A-07) |
| L-03 | trigger | O-02 | Answered |
| L-04 | happy path | AS-04, AS-05 | Answered |
| L-05 | alternate paths | AS-06, AS-09..AS-11 | Answered |
| L-06 | failure paths | AS-02, AS-12, AS-13 | Answered |
| L-07 | preconditions/state | X-02, X-03 | Answered |
| L-08 | data | §9 | Answered |
| L-09 | acceptance | §12 | Answered |
| L-10 | non-functional | §11 | Answered (N-05 open) |
| L-11 | integrations | §10 | Answered |
| L-12 | migration/backfill | RC-09 | Answered |
| L-13 | rollout | C-06 | Answered |
| L-14 | impact on existing behaviour | D-09, CT-03 | Answered |
| L-15 | observability | N-03, D-11 | Answered |
| L-16 | test level | §13 | Answered |
| L-17 | harness/fixture | CP-02 fake store | Answered |
| L-18 | regression surface | AS-18 (legacy clones) | Answered |
