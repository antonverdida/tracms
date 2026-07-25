# TRACMS Account Settings Plan

## Goal

Redesign the TRACMS account settings page so it feels like a professional government portal settings center while staying aligned with the current domain model and authentication flow.

## Current State

The current settings page in `TracmsWeb.UserLive.Settings` is still close to the default Phoenix auth implementation:

- change email
- change password
- no profile section
- no role visibility
- no office or division summary
- no notifications, sessions, or activity history

This is functional, but it reads as a generic account page rather than a TRACMS profile and security workspace.

## What The Reviewed Plan Gets Right

The reviewed proposal correctly identifies these needs:

- clearer section-based layout
- separation of email and password actions
- visible government identity and role context
- stronger account-security presentation
- room for future administrative controls

## Important Reality Check

The current schema already supports some profile information, but not the full mockup.

### Already Supported By Current Data Model

- `email`
- `full_name`
- `employee_number`
- `role`
- `office`
- `division` through the user office preload
- account status

### Not Yet Supported As User Profile Fields

- position title
- school name as a dedicated user field
- profile picture
- active session tracking
- recent account activity log
- two-factor authentication

These items should not be presented as fully interactive settings until real backend support exists.

## Recommended Implementation Strategy

Implement the settings redesign in phases.

### Phase 1: Real Settings Center

Build a polished, fully functional account settings page using data that TRACMS already has or can safely expose with minimal extension.

#### Sections

- `Profile Information`
- `Account Security`
- `Role & Access`

#### Profile Information

Show:

- full name
- employee number
- office
- division
- current email

Allow editing only for fields that have a clear ownership rule.

Recommended initial editability:

- `full_name`: editable
- `employee_number`: editable only if TRACMS policy allows self-service updates
- `office` and `division`: read-only on the personal settings page
- `email`: handled in the separate email workflow

#### Account Security

Keep the existing secure auth flow and split it into clear panels:

- current email address
- change email form
- update password form
- last authenticated session note or sudo-mode note if helpful

Important:

- keep this page under the existing authenticated settings route
- keep `on_mount {TracmsWeb.UserAuth, :require_sudo_mode}` because changing email and password is sensitive

#### Role & Access

Show a read-only access summary:

- role name
- role scope
- assigned office
- assigned division
- permissions summary derived from current role key

This should improve user clarity without adding risky self-service authorization controls.

## Recommended Layout

Use the current dashboard visual language and shared portal components.

### Page Structure

- page header
- short settings intro
- multi-panel content layout

Recommended panel order:

1. `Profile Information`
2. `Account Security`
3. `Role & Access`

### Design Notes

- keep the current TRACMS portal header and horizontal navigation
- use consistent portal panels, spacing, buttons, and form styling
- avoid tabs unless there is enough content to justify them
- prefer stacked panels over complex tab logic for Phase 1
- keep wording concise and official

## Phase 1 Backend Work

Minimal backend work:

- extend `TracmsWeb.UserLive.Settings`
- add a profile form changeset flow using `Accounts.change_user_profile/2`
- add a profile update handler using `Accounts.update_user_profile/2`
- preload and display role, office, and division context already available through `Accounts`

Possible schema addition for Phase 1:

- none required if we limit the profile form to `full_name` and possibly `employee_number`

## Phase 1 Route Placement

Keep the settings page inside the existing authenticated user route set:

- route: `/users/settings`
- live session: existing `:require_authenticated_user`

Why:

- it is personal account functionality
- it requires a logged-in user
- it already integrates with current auth and sudo mode

No new route scope is needed for Phase 1.

## Phase 2: Communication And Visibility

Only after Phase 1 is complete, add optional operational improvements:

- notification preferences
- account activity summary
- profile completeness messaging

Current progress as of Friday, July 24, 2026:

- account activity summary implemented
- profile completeness messaging implemented
- persisted notification preferences implemented

Required backend support before implementation:

- event/audit source for account activity

## Phase 3: Security Administration

Enterprise-grade controls should be deferred until there is real support:

- two-factor authentication
- login session management
- device/session revocation
- security event timeline

These are high-value features, but they require more than UI work.

## Recommended Permissions Summary Strategy

Do not let users edit permissions on their own settings page.

Instead, display a read-only summary based on role:

- `Regional Administrator`
  - manage trainings
  - approve across scope
  - review reports
  - manage certificates

- `Division Administrator`
  - review division training operations
  - approve division-scoped records
  - monitor reports in assigned scope

- `Training Coordinator`
  - manage office training activities
  - monitor attendance and completion
  - issue certificates within assigned scope

- `Participant`
  - register for trainings
  - submit evaluations
  - access certificates

## Recommended Phase 1 Outcome

After Phase 1, the settings page should feel:

- official
- structured
- informative
- secure
- consistent with the TRACMS dashboard

without pretending that advanced enterprise controls already exist.

## Next Implementation Step

Implement a Phase 1 redesign of `TracmsWeb.UserLive.Settings` with:

- a profile panel
- a security panel
- a role and access panel
- concise government-style copy
- uniform TRACMS portal panel and button styling
