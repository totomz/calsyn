# Index
1. [TASK-002 — List calendars visible to EventKit](#task-002--list-calendars-visible-to-eventkit)
2. [Definition of Done](#definition-of-done)
3. [BDD Scenarios](#bdd-scenarios)
4. [How to test](#how-to-test)

## TASK-002 — List calendars visible to EventKit

| Field            | Value                                  |
|------------------|----------------------------------------|
| **Type**         | TASK                                   |
| **ID**           | TASK-002                               |
| **Title**        | List calendars visible to EventKit     |
| **Epic**         | EP-001                                 |
| **Architecture** | Back-end, Security                     |
| **Category**     | Feature                                |
| **Actor**        | Operator                               |
| **Components**   | cli, calendar-store                    |
| Dependencies     | ---                                    |
| Blocked By       | OP-01 (minimum macOS version, advisory only) |

**Goal:** Current: the Operator has no way to know the account and title EventKit uses for a calendar.
Target: `calsyn calendars` prints one row per calendar with account and title, ready to copy into `config.yaml`.

## Definition of Done
- [ ] `calsyn calendars` prints one row per calendar visible in Calendar.app, showing account and title
  - Source evidence: `analysis.md` AS-03, C-02, J-01, D-03, D-04
- [ ] On first use macOS asks the Operator to grant Calendar access to calsyn
  - Source evidence: `analysis.md` X-03
- [ ] With Calendar access denied, any calsyn command that reads calendars logs an ERROR line and exits with a code ≠ 0
  - Source evidence: `analysis.md` AS-13, A-05
- [ ] calsyn never asks for nor stores account credentials
  - Source evidence: `analysis.md` N-04, `README.md:8-9`

## BDD Scenarios
```gherkin
Feature: List calendars visible to EventKit

  Scenario: Calendars of several accounts
    Given the Operator added an Exchange and a Google account in System Settings → Internet Accounts
    And Calendar access is granted to calsyn
    When the Operator runs `calsyn calendars`
    Then stdout shows one row per calendar with its account and title
    And the Exchange and Google calendars are both listed

  Scenario: Calendar access denied
    Given the Operator turned off calsyn in System Settings → Privacy & Security → Calendars
    When the Operator runs `calsyn calendars`
    Then stdout shows a logfmt ERROR line about Calendar access
    And the exit code is not 0
```

## How to test
| Command / action | Covers | When to run |
|---|---|---|
| Manual E2E: `calsyn calendars` on a Mac with Exchange + Google accounts | AS-03 | before closing the task |
| Manual E2E: revoke access in System Settings → Privacy & Security → Calendars, run `calsyn calendars` | AS-13 | before closing the task |
