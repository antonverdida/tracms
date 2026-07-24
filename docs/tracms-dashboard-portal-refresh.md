# TRACMS Dashboard Portal Refresh

Date: July 23, 2026
Status: Implemented and refined after browser review

## Goal

Refine the authenticated homepage so it looks and feels like a professional DepEd Region IX internal portal instead of a generic SaaS workspace.

## Adopted Direction

- Use a horizontal portal shell with clear DepEd Region IX branding.
- Rename the authenticated shell from `TRACMS Workspace` to `TRACMS Portal`.
- Keep the homepage simple, clean, and operationally focused.
- Use consistent cards, quick actions, tables, chips, and panel spacing.
- Follow the supplied dashboard mockup for structure, not for unsupported features.

## Implemented Homepage Structure

1. Greeting row with current date
2. Four summary cards for high-level operational status
3. Upcoming trainings panel
4. Status pipeline panel
5. Workflow or evaluation status panel
6. Monitoring table
7. Quick actions panel
8. Recent activity panel
9. Compact portal footer

## What Was Intentionally Removed

- `Workspace` wording in the authenticated shell
- Extra generic hero copy from the previous dashboard
- Unsupported top-level modules such as certificates, reports, documents, and participants as first-class navigation items
- Placeholder dashboard content that was not backed by actual TRACMS data

## Current Navigation Standard

The dashboard header now prioritizes implemented modules only:

- Dashboard
- Registration
- My Records
- Training Management
- Settings

`Training Management` appears only for authorized training managers.

## Role-Aware Dashboard Behavior

### Training Managers

- See management-focused metrics
- See upcoming managed activities
- See workflow and registration monitoring
- Get quick links to training creation, registrations, attendance, and completion tracking

### Participants

- See personal registration and evaluation status
- See upcoming joined trainings or open catalog opportunities
- Get quick links to browse trainings, manage records, submit evaluation, and update settings

## Design Notes

- Keep the interface light, formal, and government-appropriate
- Prefer concise wording over long marketing language
- Keep buttons, tables, chips, and panels visually uniform
- Avoid showing navigation or action buttons for modules that are not yet fully implemented

## Refinement Notes

After reviewing the live dashboard in the browser, the dashboard was refined further to:

- improve the panel hierarchy on desktop
- reduce duplicate navigation weight in the header
- shorten dashboard copy
- simplify registration queue styling
- keep only one stronger empty state in the main operational panel
- make lower-row panels quieter and more operational

## July 24 Dashboard Refinement

After reviewing the latest dashboard improvement plan, the best supported refinements for the current TRACMS codebase are:

- make the homepage more explicitly role-aware for regional administrators, division administrators, coordinators, and participants
- reduce the greeting block so operational data stays visually dominant
- enrich KPI cards with clearer breakdowns instead of generic one-line captions
- make upcoming activity cards show more useful operational context
- preserve the current implemented navigation rather than adding unsupported modules prematurely

These refinements keep the dashboard closer to a training operations command center while staying honest to the modules that already exist in the system.

## Next Recommended UI Work

1. Bring the same portal card language into training index, registrations, and attendance pages
2. Add more refined empty states for first-time users
3. Introduce role-specific notifications once the alert model exists
4. Add certificate and report sections only after those modules are implemented end to end
