# Index
1. [TASK-001 — Load and validate config via `calsyn once`](#task-001--load-and-validate-config-via-calsyn-once)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-001 — Load and validate config via `calsyn once`

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-001                               |
| **Title**        | Load and validate config via `calsyn once` |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end, Observability                |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | cli, config-loader, runner             |
| Dependencies     | ---                                    |
| Blocked By       | ---                                    |

**Goal:** Current: no program exists. Target: `calsyn once` reads `~/.config/calsyn/config.yaml` (or the file
given with `--config`), validates it, logs the outcome and exits with a code that tells success from failure.

## Definition of Done
- [ ] `calsyn once` with a valid config logs `msg="settings loaded"` with the number of calendars and jobs and exits with code 0
  - Source evidence: `analysis.md` AS-01, C-01, D-01..D-07
- [ ] `calsyn once --config <path>` reads the given file instead of `~/.config/calsyn/config.yaml`
  - Source evidence: `analysis.md` C-01, J-02
- [ ] A config with a missing required field logs an ERROR line naming the field, exits with a code ≠ 0 and writes no calendar
  - Source evidence: `analysis.md` AS-02
- [ ] A job whose `source` or `destinations` reference a `name` not declared in `calendars` logs an ERROR line naming it, exits with a code ≠ 0 and writes no calendar
  - Source evidence: `analysis.md` AS-02, D-06
- [ ] `details.title` and `details.description` default to false when omitted
  - Source evidence: `analysis.md` D-07, A-01
- [ ] Every line written by calsyn is logfmt with level INFO or ERROR
  - Source evidence: `analysis.md` AS-17, N-03

## BDD Scenarios
```gherkin
Feature: Load and validate config via `calsyn once`

  Scenario: Valid config
    Given the Operator wrote a valid `~/.config/calsyn/config.yaml` with 2 calendars and 1 job
    When the Operator runs `calsyn once`
    Then stdout shows a logfmt INFO line `msg="settings loaded" calendars=2 sync_jobs=1`
    And the exit code is 0

  Scenario: Config passed by path
    Given the Operator wrote a valid config at `/tmp/calsyn.yaml`
    When the Operator runs `calsyn once --config /tmp/calsyn.yaml`
    Then stdout shows `msg="settings loaded"`

  Scenario: Missing required field
    Given the config has a calendar without `clone_prefix`
    When the Operator runs `calsyn once`
    Then stdout shows a logfmt ERROR line naming `clone_prefix`
    And the exit code is not 0
    And no event is written to any calendar

  Scenario: Unknown calendar in a job
    Given the config has a job with destination `foo` not declared in `calendars`
    When the Operator runs `calsyn once`
    Then stdout shows a logfmt ERROR line naming `foo`
    And the exit code is not 0
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (config-loader on valid and invalid fixtures) | AS-01, AS-02 | every change |
| `swift test` (log formatter output) | AS-17 | every change |
