# Index
1. [TASK-003 — Reconcile clones of a job](#task-003--reconcile-clones-of-a-job)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-003 — Reconcile clones of a job

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-003                               |
| **Title**        | Reconcile clones of a job              |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end                               |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | reconciler, calendar-store, runner     |
| Dependencies     | TASK-001, TASK-002                     |
| Blocked By       | ---                                    |

**Goal:** Current: `calsyn once` only loads the config. Target: for each job, `calsyn once` makes every
destination hold exactly one clone per source event in the window (today → +7 days), creating the missing
clones and deleting the extra ones.

## Definition of Done
- [ ] A source event with no clone yet → after `calsyn once` each destination shows an event titled `<prefix>` with the same start and end
  - Source evidence: `analysis.md` AS-04, RC-03, RC-07
- [ ] With `details.title: true` the clone is titled `<prefix> <title>`; with `details.description: true` the clone notes show the source description
  - Source evidence: `analysis.md` AS-05, RC-07, A-04
- [ ] A source event moved, or with a cloned field changed → after the reconcile the destination shows only the updated clone
  - Source evidence: `analysis.md` AS-06, RC-04
- [ ] A source event deleted → after the reconcile its clone is gone from the destination
  - Source evidence: `analysis.md` AS-07, RC-04
- [ ] Events whose title starts with any configured `clone_prefix` are never cloned: with jobs A→B and B→A, the second consecutive `calsyn once` logs `created=0 deleted=0` for both jobs
  - Source evidence: `analysis.md` AS-08, RC-01, G3-Q2
- [ ] Clones left by the old system that match a wanted clone stay; the others are deleted
  - Source evidence: `analysis.md` AS-18, RC-09
- [ ] Each job logs one INFO summary line with `created=N deleted=N`
  - Source evidence: `analysis.md` N-03

## BDD Scenarios
```gherkin
Feature: Reconcile clones of a job

  Scenario: First clone
    Given job `work-to-home` clones calendar `work` (prefix `[W]`) into `home`
    And `work` has an event tomorrow 10:00-11:00 titled "Budget"
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` an event tomorrow 10:00-11:00 titled `[W]`
    And stdout shows `created=1 deleted=0` for `work-to-home`

  Scenario: Title and description cloned
    Given job `work-to-home` has `details.title: true` and `details.description: true`
    When the Operator runs `calsyn once`
    Then Calendar.app shows in `home` an event titled `[W] Budget` with the source description in its notes

  Scenario: Source moved
    Given the clone `[W]` exists in `home` tomorrow 10:00-11:00
    And the Operator moved "Budget" to 14:00-15:00 in Calendar.app
    When the Operator runs `calsyn once`
    Then `home` shows only one `[W]` event, at 14:00-15:00

  Scenario: Source deleted
    Given the clone `[W]` exists in `home`
    And the Operator deleted "Budget" in Calendar.app
    When the Operator runs `calsyn once`
    Then `home` shows no `[W]` event tomorrow

  Scenario: Bidirectional jobs converge
    Given jobs `work` → `home` and `home` → `work` with different prefixes
    When the Operator runs `calsyn once` twice
    Then the second run logs `created=0 deleted=0` for both jobs

  Scenario: Legacy clones
    Given `home` holds `[W]` events created by the old system, one matching "Budget" and one with no source
    When the Operator runs `calsyn once`
    Then the matching `[W]` event is still in `home`
    And the unmatched `[W]` event is gone
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| `swift test` (reconciler on the in-memory fake store) | AS-04..AS-08, AS-18 | every change |
| Manual E2E: `calsyn once` on a Mac with Exchange + Google, check both calendars in Calendar.app | AS-04, AS-05 (also observes OP-03) | before closing the task |
