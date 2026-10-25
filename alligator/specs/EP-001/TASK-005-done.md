# Index
1. [TASK-005 — Configurable time window](#task-005--configurable-time-window)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-005 — Configurable time window

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-005                               |
| **Title**        | Configurable time window               |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end                               |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | config-loader, reconciler              |
| Dependencies     | TASK-003                               |
| Blocked By       | ---                                    |

**Goal:** Current: the reconcile always works on today → +7 days. Target: `window.past_days` and
`window.future_days` in the config change the window, and nothing outside it is ever created or deleted.

## Definition of Done
- [ ] Without `window` in the config, only events from the start of today to +7 days are cloned
  - Source evidence: `analysis.md` AS-11, RC-08, D-08
- [ ] With `window.past_days` / `window.future_days` set, the clones cover exactly that range
  - Source evidence: `analysis.md` AS-11, D-08, A-08
- [ ] Source events and clones outside the window are neither created nor deleted
  - Source evidence: `analysis.md` AS-11, RC-08

## BDD Scenarios
```gherkin
Feature: Configurable time window

  Scenario: Default window
    Given the config has no `window`
    And `work` has an event in 3 days and one in 10 days
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` a `[W]` event in 3 days and none in 10 days

  Scenario: Window override
    Given the config has `window.past_days: 2` and `window.future_days: 14`
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` a `[W]` event in 10 days

  Scenario: Clones outside the window are left alone
    Given `home` holds a `[W]` event 30 days ahead with no source
    When the Operator runs `calsyn once` with the default window
    Then that `[W]` event is still in `home`
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (window boundaries and override on the fake store) | AS-11 | every change |
