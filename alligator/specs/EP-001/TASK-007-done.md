# Index
1. [TASK-007 — Resident run `calsyn run`](#task-007--resident-run-calsyn-run)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-007 — Resident run `calsyn run`

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-007                               |
| **Title**        | Resident run `calsyn run`              |
| **Epic**         | EP-001                                 |
| **Architecture** | Orchestrations                         |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | cli, runner, config-loader             |
| Dependencies     | TASK-003                               |
| Blocked By       | ---                                    |

**Goal:** Current: clones are updated only when the Operator runs `calsyn once`. Target: `calsyn run` stays
alive and reconciles at startup, after every calendar store change and every 5 minutes, one reconcile at a
time, reloading the config each time.

## Definition of Done
- [ ] `calsyn run` logs a reconcile at startup
  - Source evidence: `analysis.md` AS-14, O-02
- [ ] After the Operator edits an event in Calendar.app, the log shows a new reconcile without any command
  - Source evidence: `analysis.md` AS-14, O-02
- [ ] With no changes, the log shows a reconcile every 5 minutes
  - Source evidence: `analysis.md` AS-14, G4-Q1
- [ ] Reconciles never overlap: the log never shows a reconcile starting before the previous one ended
  - Source evidence: `analysis.md` O-03
- [ ] After the Operator edits `config.yaml` while `calsyn run` is running, the next reconcile uses the new config without a restart
  - Source evidence: `analysis.md` AS-15, C-01

## BDD Scenarios
```gherkin
Feature: Resident run `calsyn run`

  Scenario: Startup reconcile
    When the Operator runs `calsyn run`
    Then stdout shows `msg="settings loaded"` and the per-job summary lines
    And the process keeps running

  Scenario: Store change
    Given `calsyn run` is running
    When the Operator moves an event in Calendar.app
    Then stdout shows a new per-job summary line with `created=1 deleted=1`

  Scenario: Periodic reconcile
    Given `calsyn run` is running and nothing changes
    When 5 minutes pass
    Then stdout shows a new per-job summary line

  Scenario: Config reload
    Given `calsyn run` is running
    When the Operator adds a job to `~/.config/calsyn/config.yaml`
    Then the next reconcile logs a summary line for the new job
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (runner reloads config at every reconcile) | AS-15 | every change |
| Manual E2E: `calsyn run`, edit an event in Calendar.app, check stdout | AS-14 | before closing the task |
