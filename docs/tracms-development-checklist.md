# TRACMS Development Checklist

This document turns the draft checklist into a working documentation set for the current TRACMS repository.

Phase 0 is already documented in [TRACMS Phase 0 Foundation](./tracms-phase-0-foundation.md). The files below cover the next planning and implementation phases.

## Phase Index

1. [Phase 1: Project Planning](./tracms-phase-1-project-planning.md)
2. [Phase 2: Phoenix Project Setup](./tracms-phase-2-phoenix-project-setup.md)
3. [Phase 3: Project Structure](./tracms-phase-3-project-structure.md)
4. [Phase 4: Database Design](./tracms-phase-4-database-design.md)
5. [Phase 5: Authentication](./tracms-phase-5-authentication.md)
6. [Phase 6: User Role Management](./tracms-phase-6-user-role-management.md)
7. [Phase 7: LiveView Development](./tracms-phase-7-liveview-development.md)
8. [Phase 8: Tailwind Design System](./tracms-phase-8-tailwind-design-system.md)
9. [Phase 9: Dashboard Development](./tracms-phase-9-dashboard-development.md)
10. [Phase 10: Business Logic](./tracms-phase-10-business-logic.md)
11. [Phase 11: File Management](./tracms-phase-11-file-management.md)
12. [Phase 12: Email System](./tracms-phase-12-email-system.md)
13. [Phase 13: Security Checklist](./tracms-phase-13-security-checklist.md)

## Delivery Sequence

Use this sequence to keep the work incremental and low-risk:

- [x] Phase 0 foundation
- [ ] Phase 1 planning sign-off
- [ ] Phase 2 environment verification
- [ ] Phase 4 core schema design
- [ ] Phase 5 authentication baseline
- [ ] Phase 6 authorization model
- [ ] Phase 10 core contexts
- [ ] Phase 7 first LiveViews
- [ ] Phase 8 shared UI system hardening
- [ ] Phase 9 dashboard slice
- [ ] Phase 11 certificate and document pipeline
- [ ] Phase 12 transactional email
- [ ] Phase 13 production security review

## Project-Wide Notes

- TRACMS is already scaffolded as a Phoenix application, so setup work should extend the current app instead of recreating it.
- The repo uses Phoenix 1.8 conventions, including `current_scope` and `Layouts.app`.
- Tailwind in this codebase should follow Phoenix 1.8 and Tailwind v4 conventions. Do not add a legacy `tailwind.config.js` unless there is a very specific reason.
- The best near-term implementation path remains a LiveView-first monolith with PostgreSQL, Swoosh, and background jobs for slower document or notification work.

## Suggested Next Action

Start with [Phase 1: Project Planning](./tracms-phase-1-project-planning.md), then confirm the schemas in [Phase 4: Database Design](./tracms-phase-4-database-design.md) before adding new migrations or UI flows.
