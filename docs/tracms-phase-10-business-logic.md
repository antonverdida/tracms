# TRACMS Phase 10 Business Logic

## Purpose

Implement context modules that hold the real system behavior behind the LiveView interface.

## Target Contexts

- `lib/tracms/accounts.ex`
- `lib/tracms/trainings.ex`
- `lib/tracms/registrations.ex`
- `lib/tracms/attendance.ex`
- `lib/tracms/certificates.ex`
- `lib/tracms/reports.ex`

## Context Rules

- keep validation and business rules in contexts and schemas
- keep queries scoped and preload data needed by templates
- avoid placing domain decisions directly in LiveViews

## Training Context Example

Core functions:

- `create_training/2`
- `update_training/3`
- `delete_training/2`
- `list_trainings/2`

Likely supporting functions:

- `get_training!/2`
- `publish_training/2`
- `archive_training/2`
- `list_training_schedules/2`

## Business Logic Priorities

1. training lifecycle
2. registration approval
3. attendance completion calculation
4. certificate eligibility and issuance
5. report aggregation

## Phase Exit Criteria

Phase 10 is complete when:

- each major module has a stable context boundary
- UI flows call context functions instead of ad hoc repo code
- core workflows are encoded in tests
