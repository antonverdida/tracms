# TRACMS Phase 4 Database Design

## Purpose

Define the canonical TRACMS database design for the current MVP and align it with the schema already implemented in this repository.

## Canonical Modeling Decisions

- Use PostgreSQL with UUID primary keys (`:binary_id`) for all TRACMS-owned tables.
- Use `users` as the authenticated identity table. The MVP does not create a separate `participants` table.
- Model school, division, unit, and regional ownership through `offices.level` instead of separate office subtype tables.
- Treat `attendance_sessions` as the schedule/checkpoint table for trainings. A separate `training_schedules` table is not needed in the MVP.
- Keep `training_approvals` and `audit_logs` append-only.
- Store reusable certificate defaults in `certificate_layout_settings` and per-training overrides on `training_activities`.
- Support two participant shapes in `registrations`:
  - authenticated TRACMS users through `registrant_user_id`
  - guest/manual participants through `manual_participant_*` fields
- Accept that some framework support tables are part of the schema:
  - `users_tokens` for auth
  - `oban_jobs` for background work

## Timestamp Rules

- Default rule: every mutable business table has `inserted_at` and `updated_at` as `utc_datetime`.
- Append-only tables omit `updated_at`:
  - `users_tokens`
  - `training_approvals`
  - `audit_logs`
- Business event timestamps are stored separately when needed, for example:
  - `submitted_at`
  - `reviewed_at`
  - `marked_at`
  - `issued_on`
  - `delivered_at`

## Entity Inventory

### Access and organization

- `users`: login identity, profile, approval, and notification preferences
- `users_tokens`: auth/session/reset/email confirmation tokens
- `roles`: assignable access roles
- `divisions`: DepEd Region IX division master list
- `offices`: regional, division, school, and unit ownership records

### Training operations

- `training_activities`: core training record and lifecycle container
- `training_approvals`: append-only training lifecycle history
- `registrations`: participant enrollment record
- `external_registration_submissions`: imported or externally collected registration staging
- `attendance_sessions`: per-training attendance checkpoints
- `attendance_records`: participant attendance per session
- `evaluation_submissions`: participant post-training evaluation
- `certificate_records`: issued certificate records and public verification data
- `certificate_layout_settings`: reusable certificate layout defaults

### Operations and document support

- `audit_logs`: append-only operational audit trail
- `notification_deliveries`: delivery queue/result tracking for notifications
- `document_requests`: requester-facing document request intake
- `document_controls`: formal document metadata tied to a request
- `document_revision_histories`: revision history per controlled document
- `oban_jobs`: background job table managed by Oban

## Table Definitions

### `users`

- Primary key: `id uuid`
- Columns:
  - `email citext` required, unique
  - `username string` required, unique
  - `hashed_password string` optional
  - `confirmed_at utc_datetime` optional
  - `full_name string` optional
  - `employee_number string` optional
  - `status string` required, default `"pending"`
  - `approved_at utc_datetime` optional
  - `notification_preferences map` required, default all supported keys to `true`
  - `role_id uuid` optional
  - `office_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `role_id -> roles.id` on delete `SET NULL`
  - `office_id -> offices.id` on delete `SET NULL`
- Relationships:
  - belongs to `role`
  - belongs to `office`
  - has many created/reviewed/marked/approved records across the system
- Indexes:
  - unique `email`
  - unique `username`
  - index `status`
  - index `role_id`
  - index `office_id`

### `users_tokens`

- Primary key: `id uuid`
- Columns:
  - `user_id uuid` required
  - `token binary` required
  - `context string` required
  - `sent_to string` optional
  - `authenticated_at utc_datetime` optional
  - `inserted_at utc_datetime` required
- Foreign keys:
  - `user_id -> users.id` on delete `CASCADE`
- Relationships:
  - belongs to `user`
- Indexes:
  - index `user_id`
  - unique composite `context, token`

### `roles`

- Primary key: `id uuid`
- Columns:
  - `key string` required, unique
  - `name string` required
  - `description text` optional
  - `scope string` required
  - `is_assignable boolean` required, default `true`
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Relationships:
  - has many `users`
- Indexes:
  - unique `key`

### `divisions`

- Primary key: `id uuid`
- Columns:
  - `code string` required, unique
  - `name string` required, unique
  - `region string` required, default `"Region IX"`
  - `is_active boolean` required, default `true`
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Relationships:
  - has many `offices`
  - has many `training_activities`
- Indexes:
  - unique `code`
  - unique `name`

### `offices`

- Primary key: `id uuid`
- Columns:
  - `code string` required, unique
  - `name string` required
  - `level string` required
  - `email string` optional
  - `phone string` optional
  - `is_active boolean` required, default `true`
  - `division_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `division_id -> divisions.id` on delete `SET NULL`
- Relationships:
  - belongs to `division`
  - has many `users`
  - has many `training_activities`
- Indexes:
  - unique `code`
  - index `division_id`
  - index `level`

### `training_activities`

- Primary key: `id uuid`
- Columns:
  - `title string` required
  - `description text` optional
  - `category string` required
  - `training_type string` required
  - `organizer string` required
  - `modality string` required
  - `venue string` required
  - `venue_address string` required
  - `resource_speaker string` optional
  - `status string` required, default `"draft"`
  - `registration_opens_on date` optional
  - `registration_deadline utc_datetime` optional
  - `max_capacity integer` optional
  - `starts_on date` optional
  - `ends_on date` optional
  - `start_time time` optional
  - `end_time time` optional
  - `total_hours integer` optional
  - `objectives text` optional
  - `target_participants text` optional
  - `participant_qualification text` optional
  - `attendance_monitoring_method string` required
  - `certificate_type string` required
  - `certificate_layout_style string` optional
  - `certificate_accent_color string` optional
  - `certificate_header_title string` optional
  - `certificate_header_subtitle string` optional
  - `certificate_body_intro text` optional
  - `certificate_completion_statement text` optional
  - `certificate_signature_label string` optional
  - `certificate_issuing_office_label string` optional
  - `published_at utc_datetime` optional
  - `minimum_attendance_percentage integer` required, default `75`
  - `evaluation_required boolean` required, default `false`
  - `registration_form_id string` optional
  - `registration_form_url string` optional
  - `attendance_form_id string` optional
  - `attendance_form_url string` optional
  - `registration_sheet_id string` optional
  - `registration_sheet_range string` optional
  - `registration_sheet_last_synced_at utc_datetime` optional
  - `attendance_sheet_id string` optional
  - `attendance_sheet_range string` optional
  - `attendance_sheet_last_synced_at utc_datetime` optional
  - `creator_user_id uuid` optional
  - `office_id uuid` optional
  - `division_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `creator_user_id -> users.id` on delete `SET NULL`
  - `office_id -> offices.id` on delete `SET NULL`
  - `division_id -> divisions.id` on delete `SET NULL`
- Relationships:
  - belongs to `creator_user`
  - belongs to `office`
  - belongs to `division`
  - has many `training_approvals`
  - has many `registrations`
  - has many `attendance_sessions`
  - has many `external_registration_submissions`
  - has many `audit_logs`
  - has many `notification_deliveries`
- Indexes:
  - index `status`
  - index `starts_on`
  - index `creator_user_id`
  - index `office_id`
  - index `division_id`

### `training_approvals`

- Primary key: `id uuid`
- Columns:
  - `action string` required
  - `actor_role_key string` required
  - `from_status string` optional
  - `to_status string` required
  - `notes text` optional
  - `training_activity_id uuid` required
  - `acted_by_user_id uuid` optional
  - `inserted_at utc_datetime` required
- Foreign keys:
  - `training_activity_id -> training_activities.id` on delete `CASCADE`
  - `acted_by_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `training_activity`
  - belongs to `acted_by_user`
- Indexes:
  - index `training_activity_id, inserted_at`
  - index `acted_by_user_id`
  - index `action`

### `registrations`

- Primary key: `id uuid`
- Columns:
  - `status string` required, default `"submitted"`
  - `special_requirements text` optional
  - `review_notes text` optional
  - `manual_participant_name string` optional
  - `manual_participant_email string` optional
  - `submitted_at utc_datetime` required
  - `reviewed_at utc_datetime` optional
  - `training_activity_id uuid` required
  - `registrant_user_id uuid` optional
  - `reviewer_user_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `training_activity_id -> training_activities.id` on delete `CASCADE`
  - `registrant_user_id -> users.id` on delete `CASCADE`
  - `reviewer_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `training_activity`
  - belongs to `registrant_user`
  - belongs to `reviewer_user`
  - has one `certificate_record`
  - has many `attendance_records`
  - has one `evaluation_submission`
- Indexes and constraints:
  - unique composite `training_activity_id, registrant_user_id`
  - index `status`
  - index `registrant_user_id`
  - index `reviewer_user_id`
- Required/optional rule:
  - at least one participant identity must exist
  - use `registrant_user_id` for authenticated users
  - use `manual_participant_name` and optionally `manual_participant_email` for guest/manual participants
- Recommended follow-up constraint:
  - add a database check constraint enforcing `registrant_user_id IS NOT NULL OR manual_participant_name IS NOT NULL`

### `external_registration_submissions`

- Primary key: `id uuid`
- Columns:
  - `full_name string` required
  - `email string` required
  - `employee_number string` optional
  - `office_name string` optional
  - `source_reference string` optional
  - `special_requirements text` optional
  - `review_notes text` optional
  - `status string` required
  - `submitted_at utc_datetime` required
  - `reviewed_at utc_datetime` optional
  - `training_activity_id uuid` required
  - `matched_user_id uuid` optional
  - `imported_registration_id uuid` optional
  - `reviewer_user_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `training_activity_id -> training_activities.id` on delete `CASCADE`
  - `matched_user_id -> users.id` on delete `SET NULL`
  - `imported_registration_id -> registrations.id` on delete `SET NULL`
  - `reviewer_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `training_activity`
  - belongs to `matched_user`
  - belongs to `imported_registration`
  - belongs to `reviewer_user`
- Indexes:
  - index `training_activity_id`
  - index `matched_user_id`
  - index `imported_registration_id`
  - index `status`

### `attendance_sessions`

- Primary key: `id uuid`
- Columns:
  - `name string` required
  - `session_date date` required
  - `starts_at time` required
  - `ends_at time` required
  - `status string` required, default `"draft"`
  - `training_activity_id uuid` required
  - `opened_by_user_id uuid` optional
  - `closed_by_user_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `training_activity_id -> training_activities.id` on delete `CASCADE`
  - `opened_by_user_id -> users.id` on delete `SET NULL`
  - `closed_by_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `training_activity`
  - belongs to `opened_by_user`
  - belongs to `closed_by_user`
  - has many `attendance_records`
- Indexes and constraints:
  - unique composite `training_activity_id, session_date, name`
  - index `training_activity_id`
  - index `status`

### `attendance_records`

- Primary key: `id uuid`
- Columns:
  - `status string` required
  - `notes text` optional
  - `marked_at utc_datetime` required
  - `attendance_session_id uuid` required
  - `registration_id uuid` required
  - `marked_by_user_id uuid` required
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `attendance_session_id -> attendance_sessions.id` on delete `CASCADE`
  - `registration_id -> registrations.id` on delete `CASCADE`
  - `marked_by_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `attendance_session`
  - belongs to `registration`
  - belongs to `marked_by_user`
- Indexes and constraints:
  - unique composite `attendance_session_id, registration_id`
  - index `attendance_session_id`
  - index `registration_id`
  - index `status`

### `evaluation_submissions`

- Primary key: `id uuid`
- Columns:
  - `overall_rating integer` required
  - `feedback text` optional
  - `application_plan text` optional
  - `submitted_at utc_datetime` required
  - `registration_id uuid` required
  - `submitted_by_user_id uuid` required
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `registration_id -> registrations.id` on delete `CASCADE`
  - `submitted_by_user_id -> users.id` on delete `SET NULL`
- Relationships:
  - belongs to `registration`
  - belongs to `submitted_by_user`
- Indexes and constraints:
  - unique `registration_id`
  - index `submitted_by_user_id`
  - index `submitted_at`

### `certificate_records`

- Primary key: `id uuid`
- Columns:
  - `certificate_number string` required, unique
  - `verification_code string` required, unique
  - `verification_status string` required, default `"active"`
  - `certificate_type string` required
  - `issued_on date` required
  - `delivery_status string` required, default `"available"`
  - `emailed_at utc_datetime` optional
  - `downloaded_at utc_datetime` optional
  - `registration_id uuid` required, unique
  - `issued_by_user_id uuid` required
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `registration_id -> registrations.id` on delete `CASCADE`
  - `issued_by_user_id -> users.id` on delete `NO ACTION`
- Relationships:
  - belongs to `registration`
  - belongs to `issued_by_user`
- Indexes and constraints:
  - unique `registration_id`
  - unique `certificate_number`
  - unique `verification_code`
  - index `issued_on`
  - index `delivery_status`
  - index `issued_by_user_id`
  - index `verification_status`

### `certificate_layout_settings`

- Primary key: `id uuid`
- Columns:
  - `scope_key string` required, unique, default `"default"`
  - `certificate_size string` optional in DB, treated as defaulted by app
  - `layout_style string` required, default `"classic"`
  - `accent_color string` required, default `"deped_blue"`
  - `header_title string` required, default `"Department of Education"`
  - `header_subtitle string` required, default `"Region IX"`
  - `body_intro text` required, default `"This certifies that"`
  - `completion_statement text` required
  - `signature_label string` required
  - `issuing_office_label string` required
  - `asset_path string` optional
  - `asset_name string` optional
  - `asset_content_type string` optional
  - `asset_data binary` optional
  - `asset_size integer` optional
  - `document_reference_code string` required, default `"RO-ORD-F018"`
  - `revision_number string` required, default `"00"`
  - `effectivity_date date` required, default `2025-02-20`
  - `participant_name_position float` required, default `39.0`
  - `participant_name_position_source string` required, default `"fallback"`
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Relationships:
  - currently standalone by `scope_key`
- Indexes:
  - unique `scope_key`

### `audit_logs`

- Primary key: `id uuid`
- Columns:
  - `action string` required
  - `entity_type string` required
  - `entity_id string` required
  - `metadata map` required, default `%{}`
  - `actor_user_id uuid` optional in DB, required by application writes
  - `training_activity_id uuid` optional
  - `inserted_at utc_datetime` required
- Foreign keys:
  - `actor_user_id -> users.id` on delete `SET NULL`
  - `training_activity_id -> training_activities.id` on delete `SET NULL`
- Relationships:
  - belongs to `actor_user`
  - belongs to `training_activity`
- Indexes:
  - index `training_activity_id, inserted_at`
  - index `actor_user_id, inserted_at`
  - index `entity_type, entity_id, inserted_at`
  - index `action`

### `notification_deliveries`

- Primary key: `id uuid`
- Columns:
  - `type string` required
  - `status string` required, default `"queued"`
  - `payload map` required, default `%{}`
  - `delivered_at utc_datetime` optional
  - `failed_at utc_datetime` optional
  - `recipient_user_id uuid` required
  - `registration_id uuid` required
  - `training_activity_id uuid` required
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `recipient_user_id -> users.id` on delete `CASCADE`
  - `registration_id -> registrations.id` on delete `CASCADE`
  - `training_activity_id -> training_activities.id` on delete `CASCADE`
- Relationships:
  - belongs to `recipient_user`
  - belongs to `registration`
  - belongs to `training_activity`
- Indexes and constraints:
  - unique composite `type, registration_id`
  - index `recipient_user_id, inserted_at`
  - index `registration_id`
  - index `status`

### `document_requests`

- Primary key: `id uuid`
- Columns:
  - `request_number string` required, unique
  - `document_type string` required
  - `purpose text` required
  - `requested_on date` required
  - `status string` required, default `"pending"`
  - `requester_id uuid` required
  - `approved_by_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `requester_id -> users.id` on delete `RESTRICT`
  - `approved_by_id -> users.id` on delete `RESTRICT`
- Relationships:
  - belongs to `requester`
  - belongs to `approved_by`
  - has one `document_control`
- Indexes:
  - unique `request_number`
  - index `requester_id`
  - index `status`

### `document_controls`

- Primary key: `id uuid`
- Columns:
  - `document_request_id uuid` required, unique
  - `document_code string` required, unique
  - `document_title string` required
  - `revision_number string` required, default `"00"`
  - `effectivity_date date` required
  - `status string` required, default `"active"`
  - `created_by_id uuid` required
  - `approved_by_id uuid` optional
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `document_request_id -> document_requests.id` on delete `CASCADE`
  - `created_by_id -> users.id` on delete `RESTRICT`
  - `approved_by_id -> users.id` on delete `RESTRICT`
- Relationships:
  - belongs to `document_request`
  - belongs to `created_by`
  - belongs to `approved_by`
  - has many `document_revision_histories`
- Indexes:
  - unique `document_request_id`
  - unique `document_code`

### `document_revision_histories`

- Primary key: `id uuid`
- Columns:
  - `document_control_id uuid` required
  - `old_revision string` optional
  - `new_revision string` required
  - `changes_made text` required
  - `effectivity_date date` required
  - `modified_by_id uuid` required
  - `inserted_at utc_datetime` required
  - `updated_at utc_datetime` required
- Foreign keys:
  - `document_control_id -> document_controls.id` on delete `CASCADE`
  - `modified_by_id -> users.id` on delete `RESTRICT`
- Relationships:
  - belongs to `document_control`
  - belongs to `modified_by`
- Indexes:
  - index `document_control_id`

### `oban_jobs`

- Ownership: framework-managed table created by `Oban.Migrations`
- Purpose:
  - persist background jobs for reminders, notifications, imports, and other async work
- Design note:
  - treat as required infrastructure, but do not model business relationships against it directly

## Relationship Summary

- `roles 1 -> many users`
- `divisions 1 -> many offices`
- `divisions 1 -> many training_activities`
- `offices 1 -> many users`
- `offices 1 -> many training_activities`
- `users 1 -> many training_activities` through `creator_user_id`
- `training_activities 1 -> many training_approvals`
- `training_activities 1 -> many registrations`
- `training_activities 1 -> many attendance_sessions`
- `training_activities 1 -> many external_registration_submissions`
- `training_activities 1 -> many audit_logs`
- `training_activities 1 -> many notification_deliveries`
- `registrations 1 -> one evaluation_submission`
- `registrations 1 -> one certificate_record`
- `registrations 1 -> many attendance_records`
- `attendance_sessions 1 -> many attendance_records`
- `document_requests 1 -> one document_control`
- `document_controls 1 -> many document_revision_histories`

## Status and Enum Plan

- `users.status`: `pending | active | disabled`
- `roles.scope`: `system | region | division | office | participant`
- `offices.level`: `regional | division | school | unit`
- `training_activities.status`:
  - `draft`
  - `pending_division_approval`
  - `pending_region_approval`
  - `published`
  - `registration_closed`
  - `in_progress`
  - `completed`
  - `cancelled`
  - `archived`
- `training_activities.modality`: `face_to_face | online | hybrid`
- `training_approvals.action`:
  - `created`
  - `submitted_to_division`
  - `submitted_to_region`
  - `advanced_to_region_approval`
  - `published`
  - `returned_for_revision`
  - `closed_registration`
  - `reopened_registration`
  - `started`
  - `completed`
  - `cancelled`
  - `archived`
- `registrations.status`: `submitted | approved | rejected | waitlisted | withdrawn`
- `external_registration_submissions.status`: `pending_review | needs_account | imported | rejected`
- `attendance_sessions.status`: `draft | open | closed`
- `attendance_records.status`: `present | late | excused | absent`
- `certificate_records.delivery_status`: `available | emailed | downloaded`
- `certificate_records.verification_status`: `active | revoked`
- `notification_deliveries.status`: `queued | delivered | skipped | failed`
- `document_requests.status`: `pending | under_review | approved | released | rejected | archived`
- `document_controls.status`: `draft | active | superseded | archived`

## Index Strategy

- Index all foreign keys.
- Index all lifecycle/status fields used in dashboards and filters.
- Use composite indexes for time-ordered append-only views:
  - `training_approvals(training_activity_id, inserted_at)`
  - `audit_logs(training_activity_id, inserted_at)`
  - `audit_logs(actor_user_id, inserted_at)`
  - `audit_logs(entity_type, entity_id, inserted_at)`
  - `notification_deliveries(recipient_user_id, inserted_at)`
- Use business uniqueness where duplicate rows would be a correctness bug:
  - one user email
  - one username
  - one role key
  - one division code and name
  - one office code
  - one registration per user per training
  - one attendance record per registration per session
  - one evaluation per registration
  - one certificate per registration
  - one public verification code per certificate
  - one notification type per registration
  - one document control per request

## Recommended Additional Constraints

These are good follow-up migrations because the business rules already exist in application code:

- add check constraint on `registrations` requiring either `registrant_user_id` or `manual_participant_name`
- add check constraint on `attendance_sessions` requiring `ends_at > starts_at`
- add check constraint on `training_activities` for `minimum_attendance_percentage between 0 and 100`
- add check constraint on `evaluation_submissions` for `overall_rating between 1 and 5`
- add check constraint on `training_activities` so `ends_on >= starts_on` when both dates are present
- consider partial unique index for guest/manual participants if duplicate guest imports become a problem

## Planned Migration Sequence

For a clean build, this is the preferred logical order:

1. Enable `citext`; create `users` and `users_tokens`.
2. Create `roles`, `divisions`, and `offices`; then extend `users` with profile and org fields.
3. Create `training_activities` with ownership fields.
4. Create `registrations`.
5. Extend `training_activities` with training record, attendance rule, and completion rule columns.
6. Create `training_approvals`.
7. Create `attendance_sessions` and `attendance_records`.
8. Create `evaluation_submissions`.
9. Create `certificate_records`.
10. Add public verification columns and indexes to `certificate_records`.
11. Add external registration intake and Google integration fields to `training_activities`; create `external_registration_submissions`.
12. Create `certificate_layout_settings`; then add asset, size, document control, and participant positioning fields.
13. Add `notification_preferences` and `username` to `users`.
14. Create `document_requests`, `document_controls`, and `document_revision_histories`.
15. Create `audit_logs`.
16. Create `oban_jobs`.
17. Create `notification_deliveries`.
18. Add follow-up check constraints and cleanup migrations.

## Migration Notes for This Repository

- The current repository includes several repair migrations such as missing-column and missing-table fixes.
- Those repairs are appropriate for development database drift, but they are not the ideal first-pass story for a greenfield build.
- If the schema is ever squashed into a fresh baseline, preserve the end-state described in this document and fold repair steps into the canonical create/alter migrations above.

## Seed and Demo Data Plan

### Reference seeds

- roles:
  - `regional_admin`
  - `division_admin`
  - `training_coordinator`
  - `participant`
- divisions for Region IX
- offices for the regional office and each division
- one default `certificate_layout_settings` row with `scope_key = "default"`

### Demo user seeds

- one regional administrator
- one division administrator
- one training coordinator
- at least four participant accounts spread across different offices
- obviously fake local/demo credentials only

### Demo workflow seeds

- one `published` training open for registration
- one `in_progress` training with attendance underway
- one `completed` training with attendance, evaluations, and issued certificates
- one `draft` training awaiting approval
- approval history rows for each seeded training

### Demo transaction seeds

- registrations across `submitted`, `approved`, and `waitlisted`
- at least one manual/guest registration
- multiple attendance sessions for a completed training
- attendance records with `present`, `late`, and `absent` coverage
- evaluation submissions for completed participants
- certificate records for eligible completed participants
- a few external registration submissions in `pending_review` and `imported`
- optional notification delivery examples for reminder and certificate emails
- a small audit trail for training publication, attendance marking, and certificate issuance

## Out of Scope for This Phase

These concepts were mentioned in earlier planning docs but are not part of the current schema:

- separate `participants` table
- separate `schools` table
- separate `training_schedules` table
- reusable `evaluation_forms` table
- certificate issuance file storage metadata beyond the current layout and verification fields

## Phase Exit Criteria

Phase 4 is complete when:

- every MVP entity has a named table and ownership model
- required and optional fields are explicit
- primary keys, foreign keys, relationships, indexes, and unique constraints are documented
- migration order is planned
- seed/demo data coverage is planned
- the document matches the repository’s canonical end-state rather than the older placeholder model
