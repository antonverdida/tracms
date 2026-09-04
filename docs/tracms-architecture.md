# TRACMS Application Architecture

## Purpose

Define the target application architecture for TRACMS based on the codebase that already exists in this repository and the product direction documented across the planning files.

## Executive Decision

TRACMS should remain a LiveView-first modular monolith.

That means:

- one Phoenix application
- one PostgreSQL database as the system of record
- server-rendered interactive UI through LiveView
- background processing through Oban
- transactional integrations isolated behind adapter modules

This is a better fit than microservices for the current product because training, registration, attendance, certificate, notification, and audit workflows are tightly connected and need strong consistency more than independent scaling.

## Stack Summary

```text
Browser
  -> Phoenix LiveView + Controllers
  -> Domain Contexts
  -> Ecto
  -> PostgreSQL

Side systems:
- Oban for background jobs
- Swoosh for email delivery
- S3-compatible object storage for files in production
- Google Forms and Google Sheets for external data collection
```

## Architecture Decisions

### Programming language

- Elixir

Why:

- strong fit for long-running web systems
- excellent concurrency for jobs, notifications, and integrations
- matches the current codebase and team direction

### Framework

- Phoenix 1.8
- Phoenix LiveView for the internal product UI
- Bandit as the HTTP server adapter

Why:

- LiveView covers forms, tables, approvals, dashboards, and record workflows without introducing SPA complexity
- Phoenix auth and router conventions already exist in the repository

### Database

- PostgreSQL as the primary and only transactional database
- Ecto as the data access layer
- UUID primary keys across TRACMS-owned tables

Why:

- reliable relational model for auditable records
- strong support for constraints, indexing, and transactional consistency
- already aligned with the current schema and migrations

### Frontend technology

- Phoenix LiveView
- HEEx templates
- Tailwind CSS v4
- small amounts of JavaScript only for targeted hooks or browser-only behavior

Decision:

- do not build a separate React or Vue SPA for the internal system
- keep the UI server-driven unless a future public portal has clear client-side needs that LiveView cannot cover well

### Backend architecture

- modular monolith
- domain contexts under `lib/tracms/`
- web layer under `lib/tracms_web/`
- integration adapters kept behind dedicated modules
- background work delegated to Oban workers

Recommended boundaries:

- `Tracms.Accounts`
- `Tracms.Organization`
- `Tracms.Trainings`
- `Tracms.Registrations`
- `Tracms.Attendance`
- `Tracms.Evaluations`
- `Tracms.Certificates`
- `Tracms.Notifications`
- `Tracms.Reports`
- `Tracms.Audit`
- `Tracms.GoogleForms`
- `Tracms.GoogleSheets`

Rule of thumb:

- LiveViews and controllers orchestrate user interaction
- contexts own business rules
- schemas model persistence
- workers handle slow, retryable, or scheduled work
- external API calls stay in adapter modules and use `Req`

### Authentication

- Phoenix `phx.gen.auth` style session authentication
- email and password login for staff accounts
- password reset and email confirmation through token flows
- secure signed session cookies

Decision:

- internal staff actions require authenticated sessions
- public certificate verification remains unauthenticated

### Authorization

- role-based access control with organizational scope
- route protection in the router and LiveView `on_mount`
- business-rule enforcement inside contexts or policy-style helpers

Current role shape:

- regional admin
- division admin
- training coordinator
- viewer or participant roles as needed

Scope model:

- region
- division
- office
- participant

Decision:

- continue using `current_scope` as the caller contract
- do not rely on template-only hiding for security
- keep elevated actions auditable

### API requirements

- LiveView-first internal product, not API-first
- small REST JSON surface under `/api/v1`
- current public API remains limited to certificate verification
- health and readiness endpoints remain available for deployment monitoring

Decision:

- keep the MVP API narrow and read-only for public consumers
- avoid exposing registrations, attendance, or staff data over public endpoints
- add authenticated API endpoints only when there is a real external-system requirement

### File storage

- local filesystem storage for development only
- S3-compatible object storage in production for uploaded certificate assets and generated artifacts
- PostgreSQL stores metadata, ownership, and stable references

Decision:

- do not rely on ephemeral container filesystems in production
- generated PDFs and uploaded layout assets should be traceable from database records

### Email service

- Swoosh as the application mailer abstraction
- production delivery through a transactional email provider supported by Swoosh
- asynchronous delivery through Oban

Decision:

- all non-interactive email sends should be queued
- keep both HTML and plain-text variants for operational emails
- log delivery state in `notification_deliveries`

### Background jobs

- Oban for job execution, retries, and scheduling

Primary job types:

- registration notifications
- training reminders
- attendance follow-ups
- evaluation follow-ups
- future certificate generation or bulk export work

Decision:

- synchronous requests should stay fast
- slow or failure-prone work moves into jobs
- recurring reminders are scheduled through Oban Cron

### Caching

- start with no external cache
- use database queries as the source of truth
- introduce small in-memory caches only for safe read-mostly data if profiling shows a real need

Decision:

- do not add Redis for the MVP
- cache only low-risk derived data such as reference lookups or short-lived computed summaries

### Logging

- Elixir `Logger` with request IDs
- Phoenix telemetry for operational visibility
- database-backed audit logs for sensitive business events

Decision:

- separate technical logs from business audit history
- log authentication, approval, attendance override, certificate, and export events in auditable form
- production deployment should forward app logs to the hosting platform log drain or central collector

### Third-party integrations

- Google Forms for participant-facing registration and attendance collection
- Google Sheets for synchronized intake data
- QR code generation for certificate verification

Integration rules:

- keep TRACMS as the official source of approval, completion, certification, and audit status
- isolate third-party logic behind dedicated adapter modules
- authenticate Google integrations with a service account
- use `Req` for outbound HTTP

Future-compatible integrations:

- Google Drive for certificate artifact distribution
- SMS only after email flows are stable
- SSO only when deployment and identity ownership are clear

## Recommended Request Flow

```text
User action
  -> LiveView or controller
  -> context function with current_scope
  -> Ecto transaction
  -> PostgreSQL
  -> optional audit log append
  -> optional Oban job enqueue
  -> optional email or Google integration
```

## Non-Goals For The MVP

- microservices
- separate frontend SPA
- Redis or message-broker infrastructure
- broad public CRUD API
- direct end-user file repository features

## Implementation Notes

- Routes that require authentication belong in the existing authenticated router scopes and live sessions so `current_scope` is always available.
- Training management pages should continue using the authenticated browser pipeline plus training-manager authorization because they manage sensitive operational records.
- Public certificate verification should remain isolated from staff-only flows and continue using rate limiting plus minimal response payloads.

## Final Recommendation

Use this stack and structure as the TRACMS baseline:

```text
Frontend: Phoenix LiveView + HEEx + Tailwind CSS
    ↓
Framework: Phoenix 1.8 on Bandit
    ↓
Language: Elixir
    ↓
Business layer: TRACMS domain contexts
    ↓
Persistence: Ecto
    ↓
Database: PostgreSQL

Supporting services:
- Oban for background jobs
- Swoosh for email
- S3-compatible object storage for production files
- Google Forms and Google Sheets for external collection workflows
```
