# Index
1. [TASK-006 — Isolate a failing job](#task-006--isolate-a-failing-job)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-006 — Isolate a failing job

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-006                               |
| **Title**        | Isolate a failing job                  |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end, Observability                |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | runner, calendar-store                 |
| Dependencies     | TASK-003                               |
| Blocked By       | ---                                    |

**Goal:** Current: a job whose calendar is missing or read-only stops the reconcile. Target: that job logs an
ERROR and is skipped, the other jobs are reconciled.

## Definition of Done
- [ ] A job referencing a calendar not found in Calendar.app logs an ERROR line naming the job and the calendar; the other jobs are reconciled
  - Source evidence: `analysis.md` AS-12, G3-Q4
- [ ] A job with a read-only destination logs an ERROR line naming the job and the destination; the other jobs are reconciled
  - Source evidence: `analysis.md` AS-12, G3-Q4

## BDD Scenarios
```gherkin
Feature: Isolate a failing job

  Scenario: Calendar not found
    Given job `old-to-home` uses a calendar whose account was removed from Internet Accounts
    And job `work-to-home` is valid
    When the Operator runs `calsyn once`
    Then stdout shows a logfmt ERROR line naming `old-to-home` and the missing calendar
    And stdout shows the `created=N deleted=N` summary for `work-to-home`

  Scenario: Read-only destination
    Given job `work-to-holidays` has a subscribed, read-only calendar as destination
    When the Operator runs `calsyn once`
    Then stdout shows a logfmt ERROR line naming `work-to-holidays`
    And the other jobs log their summary line
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (fake store with a missing and a read-only calendar) | AS-12 | every change |
