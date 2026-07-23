# TRACMS Domain Model

Date: July 23, 2026
Status: Initial foundation

## Purpose

This document records the first domain entities added after the Phoenix scaffold and authentication setup.

## Foundation Entities

### Accounts

- `users`
  - authentication identity
  - optional organization metadata during the foundation phase
  - linked to one `role`
  - linked to one `office`

- `roles`
  - stable access keys such as `regional_admin` and `training_coordinator`
  - explicit scope classification for authorization growth

### Organization

- `divisions`
  - master list of DepEd Region IX divisions
  - includes regional grouping metadata

- `offices`
  - regional, division, school, or unit-level offices
  - optionally linked to a division

### Trainings

- `training_activities`
  - first business module in implementation
  - linked to one creator user
  - linked to one owning office
  - linked to one owning division
  - contains lifecycle state for publication and approval flow

### Registrations

- `registrations`
  - links one user to one training activity
  - tracks registration status through submission, review, and withdrawal
  - stores reviewer metadata for approval decisions

## User Metadata Added in This Slice

- `full_name`
- `employee_number`
- `status`
- `approved_at`
- `role_id`
- `office_id`

## Modeling Notes

- registration still works with minimal auth data so the generated Phoenix flow stays stable
- role and office assignment are nullable during setup and can be required later in admin workflows
- participant-specific records remain a separate future concern and are not being merged into `users`
