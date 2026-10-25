# Index
1. [TASK-010 — Open the config with `calsyn config`](#task-010--open-the-config-with-calsyn-config)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-010 — Open the config with `calsyn config`

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-010                               |
| **Title**        | Open the config with `calsyn config`   |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end                               |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | cli                                    |
| Dependencies     | TASK-001                               |
| Blocked By       | ---                                    |

**Goal:** Current: the Operator has to find and open `~/.config/calsyn/config.yaml` by hand. Target:
`calsyn config` opens the config file in the macOS default text editor (`open -t`).

## Definition of Done
- [ ] `calsyn config` opens `~/.config/calsyn/config.yaml` with `open -t` and exits with code 0
  - Source evidence: Operator request (2026-10-23)
- [ ] `calsyn config --config <path>` opens the given file instead
  - Source evidence: Operator request (2026-10-23)
- [ ] If the file does not exist, `calsyn config` creates it empty (with its parent folders) and opens it
  - Source evidence: Operator request (2026-10-23)
- [ ] If `open -t` fails, calsyn logs an ERROR line naming the path and exits with a code ≠ 0
  - Source evidence: `analysis.md` AS-17

## BDD Scenarios
```gherkin
Feature: Open the config with `calsyn config`

  Scenario: Open the default config
    Given `~/.config/calsyn/config.yaml` exists
    When the Operator runs `calsyn config`
    Then the file opens in the macOS default text editor
    And calsyn exits with code 0

  Scenario: Config missing
    Given `~/.config/calsyn/` does not exist
    When the Operator runs `calsyn config`
    Then `~/.config/calsyn/config.yaml` exists and is empty
    And the file opens in the macOS default text editor
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| Manual E2E: `calsyn config` with and without an existing config, and with `--config <path>` | all DoD items | before closing the task |
