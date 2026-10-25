# Index
1. [TASK-009 — Drop clones of canceled events](#task-009--drop-clones-of-canceled-events)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-009 — Drop clones of canceled events

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-009                               |
| **Title**        | Drop clones of canceled events         |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end                               |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | reconciler, calendar-store             |
| Dependencies     | TASK-003                               |
| Blocked By       | ---                                    |

**Goal:** Current: a canceled source event is still cloned. Target: canceled source events are never cloned, and
the clones they already have are deleted at the next reconcile.

## Definition of Done
- [ ] A source event whose status is canceled → after `calsyn once` no destination has a clone of it
  - Source evidence: Operator request (2026-10-23)
- [ ] A source event canceled after it was cloned → after the next reconcile its clone is gone from every destination
  - Source evidence: Operator request (2026-10-23)

## BDD Scenarios
```gherkin
Feature: Drop clones of canceled events

  Scenario: Canceled event is not cloned
    Given job `work-to-home` clones calendar `Exchange/Calendar` (prefix `[W]`) into `Google/@gMail`
    And `Exchange/Calendar` has a canceled event tomorrow 10:00-11:00
    When the Operator runs `calsyn once`
    Then Calendar.app shows no `[W]` event in `Google/@gMail` tomorrow 10:00-11:00

  Scenario: Event canceled after cloning
    Given the clone `[W]` exists in `Google/@gMail` tomorrow 10:00-11:00
    And the organizer cancels the source event
    When the Operator runs `calsyn once`
    Then the `[W]` event is gone from `Google/@gMail`
    And stdout shows `deleted=1` for `work-to-home`
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (fake store with a canceled source event) | both DoD items | every change |
| Manual E2E: an Exchange meeting canceled by its organizer, run `calsyn once`, check the destination in Calendar.app | both DoD items | before closing the task |
