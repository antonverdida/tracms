# TRACMS Attendance MVP

Date: July 23, 2026
Status: Planned for implementation

## Objective

Implement the first attendance module for TRACMS using a simple, professional, and auditable workflow that fits the current training and registration features.

## Scope

- Session-based attendance for each training activity
- Manual attendance marking by authorized training managers
- Attendance roster limited to approved registrations
- Shared TRACMS dashboard layout and existing button, panel, and table styles

## MVP Decisions

1. Use attendance sessions instead of one flat training-level attendance sheet.
2. Start with manual marking only.
3. Exclude QR attendance from this step.
4. Exclude certificate eligibility and certificate issuance from this step.
5. Keep status choices simple: `present`, `late`, `excused`, `absent`.

## Data Model

### `attendance_sessions`

- belongs to `training_activities`
- fields:
  - `name`
  - `session_date`
  - `starts_at`
  - `ends_at`
  - `status` with MVP flow `draft -> open -> closed`
  - `opened_by_user_id`
  - `closed_by_user_id`

### `attendance_records`

- belongs to `attendance_sessions`
- belongs to `registrations`
- fields:
  - `status`
  - `notes`
  - `marked_at`
  - `marked_by_user_id`

## UI Plan

Create one manager-facing page first:

- Route: `/trainings/:training_id/attendance`
- Top section:
  - training context
  - create session form
  - session list with active state
- Main section:
  - approved participant roster for the selected session
  - one-click status actions
  - simple status summary

## Guardrails

- Only authenticated training managers can access attendance management.
- Only registrations for the same training can be marked.
- Attendance changes must be server timestamped.
- One record per registration per session.
- Unapproved, rejected, and withdrawn registrations are excluded from the roster.

## Follow-up After MVP

- QR attendance windows
- duplicate scan protection
- attendance percentage computation
- completion rules
- certificate eligibility and issuance
