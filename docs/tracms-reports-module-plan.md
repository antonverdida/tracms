# TRACMS Reports Module Plan

Date: July 24, 2026
Status: In progress

## Goal

Implement the first real reporting module backed by current TRACMS data so the dashboard can eventually point to an actual Reports page instead of a placeholder concept.

## Why Reports First

- The current codebase already has real training, registration, attendance, and completion data.
- Reports can be implemented honestly without inventing certificate issuance records that do not yet exist.
- Government users need management summaries, operational monitoring, and accomplishment-style views.

## Supported Scope for Version 1

Build a manager-only Reports page that includes:

- summary cards for trainings, participants, attendance sessions, and completion-ready records
- a training accomplishment table
- a registration status summary
- an attendance operations summary
- a completion readiness summary

## Route Placement

Place the new page inside the existing `live_session :training_management` block in the router because:

- it requires authenticated access
- it should only be available to training managers
- it relies on the existing `TracmsWeb.TrainingLive.Auth` authorization and `@current_scope`

## Design Direction

- use the shared portal header, stat cards, panel headers, and panel layout
- keep the page simple and professional
- prioritize readable operations summaries over export-heavy report UI
- avoid adding unsupported certificate issuance claims

## Version 1 Limitations

- no PDF or spreadsheet export yet
- no standalone certificate issuance report until a real certificate model exists
- no extra navigation items beyond the modules that are actually implemented

## Expected Result

TRACMS will have a real Reports page that management users can open from the authenticated shell and use to review operational summaries across trainings, registrations, attendance, and completion.
