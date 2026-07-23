# TRACMS Evaluation And Completion MVP

Date: July 23, 2026
Status: Planned for implementation

## Objective

Extend the attendance module so TRACMS can compute participant completion status using attendance rules and evaluation submission requirements.

## Scope

- Add completion rule fields to each training activity
- Add one evaluation submission record per approved registration
- Add a participant evaluation submission page
- Add a manager completion summary page

## MVP Decisions

1. Keep completion rules on the training activity itself.
2. Require approved registration before a participant can submit evaluation data.
3. Support one evaluation submission per registration, with updates allowed.
4. Count `present`, `late`, and `excused` as earned attendance for completion percentage.
5. Compute completion from system records only, not manual completion flags.

## Completion Rules

A participant is `completed` only when:

- registration status is `approved`
- attendance percentage meets or exceeds the training minimum
- evaluation submission exists when the training requires evaluation

## Data Model

### Training activity additions

- `minimum_attendance_percentage`
- `evaluation_required`

### `evaluation_submissions`

- belongs to `registrations`
- belongs to `submitted_by_user`
- fields:
  - `overall_rating`
  - `feedback`
  - `application_plan`
  - `submitted_at`

## UI Plan

### Participant flow

- Add an evaluation action from `My Registrations`
- Use a clean single-page evaluation form with training context and short guidance

### Manager flow

- Add a completion summary page at `/trainings/:training_id/completion`
- Show:
  - approved participant roster
  - attendance percentage
  - evaluation submitted state
  - computed completion status

## Guardrails

- Only the owner of the registration can submit or update evaluation
- Only approved registrations can have evaluation submissions
- Completion remains computed and read-only
- Attendance and evaluation data must stay separate from certificate issuance logic

## Follow-up After MVP

- evaluation templates and custom question sets
- post-training evaluation windows
- certificate eligibility queue
- certificate generation and release
