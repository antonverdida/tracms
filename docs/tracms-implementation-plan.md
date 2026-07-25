# TRACMS Implementation Plan

## 1. Executive Recommendation

The attached concept is strong, but it is too broad to build all at once without creating unnecessary complexity. The best implementation path is:

1. Build a clean Phoenix 1.8 + LiveView monolith first.
2. Ship a focused MVP around training lifecycle management.
3. Standardize the UI early with a small component system.
4. Treat certificates, attendance, approvals, and audit logs as first-class records.
5. Add advanced reporting, document repository depth, and integrations only after the core workflow is stable.

For this project, a monolith is better than a microservice approach because:

- the repository is currently empty
- the workflow is tightly connected end to end
- the user base is organizational rather than public-consumer scale
- Phoenix LiveView can deliver a professional admin experience with less frontend complexity
- a single codebase will be easier for government teams to maintain

## 2. Recommended Stack

### Core Stack

- Backend: Elixir + Phoenix 1.8
- Frontend: Phoenix LiveView
- Database: PostgreSQL
- Background jobs: Oban
- Email: Swoosh
- File storage: local in development, S3-compatible object storage in production
- PDF generation: HTML-to-PDF service or headless Chromium-based rendering
- QR generation: server-side QR code library
- Deployment: Docker

### Why This Stack Fits TRACMS

- LiveView is a strong fit for forms, dashboards, tables, filters, approvals, and admin workflows.
- Phoenix 1.8 has better built-in auth scaffolding and clearer authorization structure than older project templates.
- Oban is a strong fit for certificate generation, bulk email sending, retries, scheduled reminders, and report exports.
- Swoosh integrates cleanly with Phoenix for transactional email delivery.

## 3. Product Direction

The best version of TRACMS is not "feature-heavy first." It should be:

- simple
- professional
- accessible
- auditable
- reliable
- consistent

That means phase 1 should optimize for:

- accurate records
- clear approval workflow
- dependable attendance capture
- controlled certificate issuance
- easy retrieval of participant history
- exportable reports

It should avoid phase-1 complexity such as:

- mobile app
- LMS integration
- HRIS integration
- advanced AI recommendations
- deep public-facing marketing pages
- too many role variations beyond what is operationally necessary

## 4. Best Scope for MVP

### Include in MVP

1. Authentication and role-based access
2. Regional, division, and coordinator dashboards
3. Training activity creation and approval
4. Public/internal registration form
5. Participant approval and list management
6. Attendance monitoring
7. Evaluation form
8. Certificate generation and release
9. Public certificate verification
10. Participant training history
11. CSV/Excel-first reporting
12. Audit logs for sensitive actions

### Delay to Phase 2

1. Advanced document repository workflows
2. SMS notifications
3. Single sign-on
4. Full analytics warehouse style reporting
5. Complex workflow customization per office
6. CPD credit integration
7. Native mobile app

## 5. Recommended Domain Model

The original brief is correct at the module level, but the implementation should use clean domain boundaries.

### Core Entities

- `users`
- `roles`
- `offices`
- `divisions`
- `schools`
- `participants`
- `training_activities`
- `training_schedules`
- `training_approvals`
- `registrations`
- `attendance_sessions`
- `attendance_records`
- `evaluation_forms`
- `evaluation_submissions`
- `certificate_templates`
- `certificate_issuances`
- `verification_logs`
- `documents`
- `audit_logs`

### Important Modeling Decisions

#### 1. Separate users from participant profile data

Some participants will be system users, but the participant record should still be its own business entity. This prevents the training history from being too tightly coupled to login accounts.

#### 2. Separate training activity from schedule/session records

One training may span multiple dates or multiple check-in events. Attendance should not be stored directly on the training record.

#### 3. Separate registration from attendance

Registration means the participant applied or was accepted. Attendance means the participant actually appeared in one or more sessions.

#### 4. Separate certificate issuance from certificate template

Templates are reusable. Issuances are immutable records tied to a person, training, and eligibility result.

#### 5. Keep audit logs append-only

Do not overwrite sensitive history for approvals, certificate issuance, and administrative changes.

## 6. Workflow Recommendation

The best workflow for simplicity and accountability is:

`draft -> pending_division_approval -> pending_region_approval -> published -> registration_closed -> in_progress -> completed -> archived`

### Registration Flow

`submitted -> under_review -> approved -> rejected -> waitlisted -> withdrawn`

### Certificate Flow

`not_eligible -> eligible -> queued -> generated -> released -> reissued`

This is simpler and safer than trying to support many custom workflow states early.

## 7. Attendance Strategy

Attendance is one of the highest-risk modules because bad attendance data leads to bad certificates.

### Best Implementation

Use two attendance modes in MVP:

1. Manual check-in/check-out by coordinator
2. QR-based self check-in backed by server validation

### Recommendation

- QR should be tied to a registration record, not only to the training itself.
- If the training has multiple schedule blocks, attendance should be recorded per session.
- Completion should be computed from session attendance, not manually typed.
- Certificate eligibility should be calculated from attendance percentage plus evaluation rules.

### Anti-abuse Rules

- short-lived QR attendance windows
- duplicate scan protection
- server-side timestamping
- manual override with audit trail

## 8. Certificate Strategy

Certificates should be treated as formal records, not just downloadable files.

### Best Implementation

- generate a unique certificate number
- generate a verification token or signed public identifier
- embed QR code on the PDF
- store issuance metadata in the database
- store the final generated PDF path separately from the template

### Eligibility Rules

Phase 1 should support configurable rules per training:

- minimum attendance percentage
- evaluation submission required or not
- approved participant status required

### Public Verification Page

The public verification page should show only:

- certificate status
- participant name
- training title
- date issued
- issuing office

Avoid exposing unnecessary internal data.

## 9. UI and Design System Recommendation

This is where we should enforce the uniform implementation you asked for.

### Design Principle

Do not style pages one by one.

Create a small TRACMS component system first and use it everywhere.

### Base Design Tokens

- color tokens
- spacing scale
- border radius scale
- shadow scale
- typography scale
- status colors

### Required Reusable Components

- button
- input
- select
- textarea
- checkbox
- radio group
- date/time input
- file upload
- modal
- drawer or slide-over
- card or panel
- data table
- filter bar
- badge or status chip
- alert
- empty state
- pagination
- tabs
- breadcrumb
- stats summary block

### Button Rules

Only these button variants in phase 1:

- primary
- secondary
- ghost
- danger

Every page should use the same sizing, radius, hover, disabled, and focus rules.

### Modal Rules

- Use modals only for confirmation, quick edits, and focused tasks.
- Use full pages for long forms like training creation or template editing.
- Keep modal sizes standardized: `sm`, `md`, `lg`.

### Table Rules

- all admin listing pages should share one table pattern
- same filter row structure
- same bulk action layout
- same empty state
- same loading state

### Form Rules

- use vertical layout by default
- show help text consistently
- keep validation messaging close to the field
- use server-side validation as the source of truth

## 10. Branding Recommendation

For accuracy, the UI should align with official DepEd identity rather than inventing a new brand system.

### Recommendation

- use a clean government-style interface
- use neutral backgrounds and surfaces
- use official DepEd branding accents where appropriate
- keep contrast high and typography formal
- avoid overly decorative gradients or trendy startup-style visuals

Important note:
The attached brief suggests "DepEd Blue" and gold, but the official DepEd logo guidance is older and uses specific logo typography and color references. For the application UI, the safest approach is:

- neutral interface palette for readability
- consistent government portal styling
- official DepEd logo and institutional identity used correctly in header, login, certificate, and public verification pages

## 11. Security and Accuracy Requirements

TRACMS should be built as a records system, not only as a convenience app.

### Must-Have Security Measures

1. Built-in Phoenix auth foundation
2. Role-based authorization in both route access and LiveView events
3. Audit logs for approvals, attendance overrides, certificate generation, and account changes
4. Strict file upload validation
5. Signed or hard-to-guess certificate verification identifiers
6. Soft-delete or archive policies for records that must remain historically traceable
7. Database constraints for uniqueness and data integrity
8. Background jobs for long-running actions
9. Backup and restore plan
10. Environment-based configuration for mail, storage, and secrets

### Accuracy Controls

- no certificate issuance without computed eligibility
- no public verification without a persisted issuance record
- no approval transitions without role checks
- no attendance edits without audit logging
- no duplicate participant records without identity matching rules

## 12. Best Phoenix Architecture

### Recommended Contexts

- `Accounts`
- `Organization`
- `Trainings`
- `Registrations`
- `Attendance`
- `Evaluations`
- `Certificates`
- `Documents`
- `Reports`
- `Audit`

This is more maintainable than putting everything into one large context.

### Route Layout

- Public pages
  - training browse
  - registration
  - certificate verification
- Authenticated participant pages
  - my registrations
  - my certificates
  - my training history
- Admin/coordinator pages
  - dashboard
  - trainings
  - participants
  - attendance
  - certificates
  - reports
  - settings

### LiveView Use

Use LiveView for:

- dashboards
- forms
- approvals
- participant lists
- attendance screens
- certificate queues
- reporting filters

Use regular controller endpoints where simpler:

- file downloads
- public verification endpoint if needed
- health checks

## 13. Reporting Strategy

For phase 1, reports should be practical before they are sophisticated.

### Build First

- participant lists
- attendance sheets
- certificate issuance lists
- training completion summary
- division participation summary
- participant training history export

### Export Formats

- CSV first
- Excel second if needed
- PDF only for formal printable summaries

This keeps the first implementation faster and more reliable.

## 14. Recommended Delivery Phases

### Phase 0: Project Foundation

- generate Phoenix app
- configure PostgreSQL
- set up auth
- define role model
- define design tokens and component library
- set up Docker and environment config
- set up CI, formatter, test base

### Phase 1: Core Training Lifecycle MVP

- training CRUD
- approval workflow
- publication
- registration form
- participant approval
- participant portal basics

### Phase 2: Attendance and Evaluation

- session-based attendance
- QR attendance
- evaluation form and submissions
- completion computation

### Phase 3: Certificate Issuance

- template management
- eligibility engine
- PDF generation
- QR verification
- email release
- participant downloads

### Phase 4: Reports and Audit Hardening

- report pages
- exports
- audit views
- admin oversight tools

### Phase 5: Production Readiness

- permissions review
- data backup drills
- performance review
- user acceptance testing
- deployment hardening

## 15. First Implementation Priorities

Before building feature pages, we should implement these foundations first:

1. project scaffold
2. auth and roles
3. design system components
4. organization master data
5. training data model
6. approval workflow

This order will reduce rework.

## 16. Suggested Folder and Documentation Structure

Create these docs early:

- `docs/tracms-implementation-plan.md`
- `docs/tracms-domain-model.md`
- `docs/tracms-ui-system.md`
- `docs/tracms-mvp-scope.md`
- `docs/tracms-deployment-notes.md`

For now, this file is the master plan.

## 17. Risks to Avoid

1. Building every module from the brief immediately
2. Mixing participant identity, account identity, and employee identity into one fragile table
3. Using ad hoc styling instead of a component system
4. Generating certificates without durable verification records
5. Treating QR attendance as trusted without backend validation
6. Putting too much business logic inside LiveViews instead of contexts
7. Overusing modals for large forms
8. Adding external integrations before the internal workflow is correct

## 18. Final Recommendation

The best implementation is:

- a single Phoenix LiveView application
- with a strict component system
- a narrow but complete MVP
- session-based attendance
- rule-based certificate issuance
- strong audit logging
- practical exports
- government-style accessibility and consistency

This will give TRACMS a simple and professional foundation while keeping the system accurate, maintainable, and ready for future expansion.

## 19. References Used for This Plan

- Phoenix 1.8 release notes: https://www.phoenixframework.org/blog/phoenix-1-8-released
- Phoenix LiveView documentation: https://hexdocs.pm/phoenix_live_view/1.0.7/welcome.html
- Phoenix LiveView security considerations: https://phoenix-live-view.hexdocs.pm/security-model.html
- Oban documentation: https://oban.hexdocs.pm/
- Oban periodic jobs: https://hexdocs.pm/oban/periodic_jobs.html
- Swoosh documentation: https://swoosh.hexdocs.pm/Swoosh.html
- GOV.UK Design System components: https://design-system.service.gov.uk/components/
- U.S. Web Design System components: https://designsystem.digital.gov/components/overview/
- U.S. Web Design System modal guidance: https://designsystem.digital.gov/components/modal/
- U.S. Web Design System form guidance: https://designsystem.digital.gov/components/form/
- OWASP Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- OWASP File Upload Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- OWASP Logging Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- DepEd logo guidance: https://www.deped.gov.ph/2003/08/20/do-69-s-2003-deped-logo/
- DepEd Region IX site: https://www.depedro9.info/
- DepEd regional/division directory: https://www.deped.gov.ph/contact-us/regional-division-offices-directory/
