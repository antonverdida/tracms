# TRACMS Operational Pages Portal Refresh

## Goal

Extend the shared portal design system into the next authenticated operational pages that are already implemented in TRACMS.

## Actual Next Targets

Based on the current router and LiveView modules, the next pages to align are:

- Training registrations review
- Attendance management
- Completion summary
- Participant evaluation

## Why These Pages Next

- They are high-frequency operational pages for training coordinators and participants.
- They still use older generic panel and table patterns.
- They are directly connected to the dashboard and inner pages that were already refreshed.
- They benefit immediately from the shared portal header, stat-card, panel-header, and empty-state components.

## Refresh Direction

- Keep the page shell consistent with the dashboard and refreshed inner pages.
- Add concise summary cards where they improve quick scanning.
- Replace generic empty states with clearer operational guidance.
- Keep action buttons, status chips, and tables visually uniform.
- Preserve the current workflows and route structure without changing the underlying behavior.

## Page-Level Implementation Plan

### Training Registrations Review

- Add a portal page header
- Add summary cards for total, pending, approved, and non-approved decisions
- Rework the registrations table into a denser operational review panel

### Attendance Management

- Add a portal page header and overview cards
- Keep the create-session form and session list, but align them to the portal panel structure
- Rework the selected-session roster area for better scanability
- Improve no-session and no-roster empty states

### Completion Summary

- Add a portal page header and summary cards
- Clarify completion rules in a compact criteria panel
- Rework the participant completion list to match the portal table language

### Participant Evaluation

- Add a portal page header and contextual summary cards
- Keep the form simple and professional
- Make the supporting training context panel more structured and easier to scan

## Implementation Rule

Only apply the portal system to pages that already exist and are fully wired in the current application. Do not add unsupported modules or navigation items just to match external mockups.

## Result

The training registrations, attendance, completion, and participant evaluation pages now follow the same portal header, summary-card, panel, empty-state, and status-chip system used by the refreshed dashboard and inner pages.
