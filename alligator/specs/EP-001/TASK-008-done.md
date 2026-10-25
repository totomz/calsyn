# Index
1. [TASK-008 — Install/uninstall LaunchAgent](#task-008--installuninstall-launchagent)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-008 — Install/uninstall LaunchAgent

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-008                               |
| **Title**        | Install/uninstall LaunchAgent          |
| **Epic**         | EP-001                                 |
| **Architecture** | Infrastructure, Orchestrations         |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | cli, launch-agent                      |
| Dependencies     | TASK-007                               |
| Blocked By       | ---                                    |

**Goal:** Current: `calsyn run` lives only while the Operator keeps a terminal open. Target: `calsyn install`
makes launchd keep `calsyn run` alive in the user session; `calsyn uninstall` removes it.

## Definition of Done
- [ ] `calsyn install` copies the binary to `~/.calsyn/bin`, writes `~/Library/LaunchAgents/com.totomz.calsyn.plist` and loads it
  - Source evidence: `analysis.md` AS-16, C-06, D-10
- [ ] After `calsyn install`, `launchctl list` shows `com.totomz.calsyn` and `~/Library/Logs/calsyn.log` grows with reconcile lines
  - Source evidence: `analysis.md` AS-16, O-01, D-11
- [ ] After a logout/login the agent is running again
  - Source evidence: `analysis.md` O-01 (RunAtLoad, KeepAlive)
- [ ] `calsyn uninstall` unloads the agent and removes the plist: `launchctl list` no longer shows `com.totomz.calsyn`
  - Source evidence: `analysis.md` AS-16, C-06

## BDD Scenarios
```gherkin
Feature: Install/uninstall LaunchAgent

  Scenario: Install
    Given the Operator built calsyn from source and `calsyn once` succeeds
    When the Operator runs `calsyn install`
    Then `~/.calsyn/bin/calsyn` exists
    And `launchctl list` shows `com.totomz.calsyn`
    And `~/Library/Logs/calsyn.log` shows `msg="settings loaded"`

  Scenario: Uninstall
    Given calsyn is installed
    When the Operator runs `calsyn uninstall`
    Then `launchctl list` no longer shows `com.totomz.calsyn`
    And `~/Library/LaunchAgents/com.totomz.calsyn.plist` does not exist
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| Manual E2E: `calsyn install`, `launchctl list`, `tail ~/Library/Logs/calsyn.log`, `calsyn uninstall` | AS-16 | before closing the task |
