# Index
1. [TASK-004 — Clone every kind of source event](#task-004--clone-every-kind-of-source-event)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-004 — Clone every kind of source event

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-004                               |
| **Title**        | Clone every kind of source event       |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end                               |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | reconciler, calendar-store             |
| Dependencies     | TASK-003                               |
| Blocked By       | ---                                    |

**Goal:** Current: the reconcile is proven only on single timed events. Target: recurring, all-day, declined,
free and tentative source events are cloned too, recurring occurrences as standalone events.

## Definition of Done
- [ ] A recurring source event → the destination shows one standalone, non-recurring clone per occurrence inside the window
  - Source evidence: `analysis.md` AS-09, RC-05
- [ ] All-day, declined, free and tentative source events are cloned
  - Source evidence: `analysis.md` AS-10, RC-06
- [ ] The clone of an all-day event is an all-day event
  - Source evidence: `analysis.md` AS-10, RC-07

## BDD Scenarios
```gherkin
Feature: Clone every kind of source event

  Scenario: Recurring event
    Given `work` has a daily standup 09:00-09:15 recurring every weekday
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` one `[W]` event per weekday in the window
    And opening one of them in Calendar.app shows no repeat rule

  Scenario: All-day event
    Given `work` has an all-day event tomorrow
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` an all-day `[W]` event tomorrow

  Scenario: Declined, free and tentative events
    Given `work` has a declined, a free and a tentative event tomorrow
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` three `[W]` events at the same times
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (reconciler with recurring, all-day, declined, free, tentative fixtures) | AS-09, AS-10 | every change |
| Manual E2E: real recurring event on Exchange, `calsyn once`, check Calendar.app | AS-09 | before closing the task |
