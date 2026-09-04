# TRACMS Phase 6 User Role Management

## Purpose

Add clear authorization boundaries so users only see and perform actions allowed by their role.

## Baseline Roles

- Administrator
- Training Manager
- Encoder
- Viewer
- Participant

## Recommended Permission Model

Tables:

- `roles`
- `permissions`
- `user_roles`
- `role_permissions`

Example permissions:

- `can_create_training`
- `can_edit_training`
- `can_publish_training`
- `can_manage_registrations`
- `can_manage_attendance`
- `can_generate_certificate`
- `can_view_reports`
- `can_manage_users`

## Policy Guidance

- Keep permissions action-oriented.
- Check authorization in contexts or dedicated policy modules, not only in templates.
- Log elevated actions such as overrides, approvals, and certificate reissues.

## Suggested First Mapping

- Administrator: full access
- Training Manager: training, registration, attendance, certificate, and report management
- Encoder: registration and attendance operations with limited publishing powers
- Viewer: read-only access to approved data
- Participant: own registrations, attendance summary, and certificate lookup if self-service is enabled

## Phase Exit Criteria

Phase 6 is complete when:

- roles are stored in the database
- sensitive actions are permission-checked
- the UI hides unsupported actions and the backend still enforces the same rules
