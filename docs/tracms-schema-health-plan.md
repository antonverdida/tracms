# TRACMS Schema Health Plan

Date: July 24, 2026
Status: In progress

## Goal

Add a repeatable schema-health check so TRACMS can detect missing critical tables or columns before runtime errors appear in the UI.

## Scope

Implement:

- a reusable schema-health module in the application layer
- a `mix tracms.schema.health` command for manual checks
- coverage for critical TRACMS tables and columns
- `precommit` integration so the check runs in `test` after migrations

## Design Rules

- check the physical database schema, not only `schema_migrations`
- focus on core tables and columns that the current application actually depends on
- fail loudly when drift is found
- keep output simple enough for day-to-day developer use

## Non-Goals

- no automatic repair in the health task
- no diff against every single historical migration file
- no production deployment automation in this phase
