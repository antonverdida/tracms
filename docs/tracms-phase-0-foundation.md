# TRACMS Phase 0 Foundation

## Purpose

Phase 0 exists to make the project stable before domain features are added. The goal is to avoid a fast but messy start.

## What Was Done

1. Phoenix 1.8 application scaffolded in the repository root.
2. Dependencies fetched successfully.
3. Project generator defaults updated to use UTC timestamps and binary IDs for future schemas.
4. Starter Phoenix homepage replaced with a TRACMS-oriented project shell.
5. Initial TRACMS UI baseline started in `assets/css/app.css`.
6. Generic Phoenix demo layout adjusted to a government-style application shell.
7. Phase 0 documentation added to support the implementation path.

## Current Foundation Decisions

### Architecture

- single Phoenix monolith
- LiveView-first user experience
- PostgreSQL as primary datastore
- object storage planned for generated certificates and uploaded documents

### UI Direction

- fixed light theme for now
- no theme toggle in Phase 0
- shared button variants
- shared panel and metric card styles
- shared form field classes
- shared table shell styles

### Records Direction

The system will later separate:

- accounts
- participants
- trainings
- schedules
- registrations
- attendance
- evaluations
- certificate issuances
- audit logs

## What Is Not Done Yet

- authentication
- role authorization
- organization master data
- database creation and migrations
- first business contexts
- test execution
- asset installer execution for Tailwind and esbuild binaries

## Next Recommended Slice

The next slice should implement:

1. authentication foundation
2. role model
3. organization structures such as divisions and offices
4. initial training activity schema and workflow states
