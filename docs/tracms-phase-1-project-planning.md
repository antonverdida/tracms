# TRACMS Phase 1 Project Planning

## Purpose

Define the operational shape of TRACMS before expanding the data model or UI surface.

## Requirements Checklist

- [ ] Define system objectives
- [ ] Identify users and roles
- [ ] Define modules
- [ ] Define workflows
- [ ] Define reports needed
- [ ] Define data retention policy
- [ ] Define security requirements

## Working System Objectives

TRACMS should:

- manage end-to-end training records
- support internal staff and participants with clear role boundaries
- keep attendance, evaluation, and certificate records auditable
- generate operational and compliance reports quickly
- reduce manual spreadsheet and paper-based tracking

## Users And Roles

Primary users:

- Administrator
- Training Manager
- Encoder
- Viewer
- Participant

Supporting organizational scope:

- regional office staff
- division coordinators
- training facilitators
- records or audit reviewers

## Module Checklist

- [ ] Authentication
- [ ] User Management
- [ ] Training Management
- [ ] Registration
- [ ] Attendance
- [ ] Certificate Management
- [ ] Reports
- [ ] Notifications
- [ ] Audit Logs

## Recommended Core Workflows

Training workflow:

`draft -> pending_approval -> published -> registration_closed -> in_progress -> completed -> archived`

Registration workflow:

`submitted -> under_review -> approved -> rejected -> waitlisted -> withdrawn`

Certificate workflow:

`not_eligible -> eligible -> generated -> released -> revoked`

## Reports To Define Early

- training summary by date range
- participant completion report
- attendance completion report
- certificate issuance log
- pending approval queue
- user activity and audit log export

## Data Retention Policy Questions

- How long should completed training records remain editable?
- How long should audit logs be retained?
- Should deleted records be soft-deleted instead of removed?
- Which documents must remain available for compliance review?

Recommended starting point:

- training, attendance, and certificate records are retained indefinitely
- audit logs are append-only and retained indefinitely
- user-facing deletions default to archival or deactivation, not hard delete

## Security Requirements

- authentication for staff-only functions
- role-based authorization on every sensitive action
- append-only audit coverage for approvals, attendance overrides, and certificate issuance
- secure session handling
- server-side validation for all forms and imports
- rate limiting for public verification endpoints

## Planning Exit Criteria

Phase 1 is complete when:

- objectives are approved
- roles are approved
- module scope is confirmed
- workflows are signed off
- report list is prioritized
- retention and security baselines are documented
