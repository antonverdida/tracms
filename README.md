# TRACMS

DepEd Region IX Training, Registration, Attendance, and Certification Management System.

## Current Status

The project is now in Phase 0 foundation work:

- Phoenix 1.8 application scaffolded in-place
- PostgreSQL-oriented project structure ready
- base TRACMS visual system started
- planning documents created before feature implementation

## Stack

- Elixir 1.17
- Phoenix 1.8
- Phoenix LiveView
- PostgreSQL
- Oban and Swoosh planned for core background work and email delivery

## Local Setup

1. Install dependencies with `mix deps.get`
2. Configure the database in `config/dev.exs`
3. Create the database with `mix ecto.create`
4. Start the server with `mix phx.server`

Open [http://localhost:4000](http://localhost:4000) after the server starts.

## Key Docs

- [Implementation plan](./docs/tracms-implementation-plan.md)
- [Phase 0 foundation](./docs/tracms-phase-0-foundation.md)
- [UI system](./docs/tracms-ui-system.md)

## Next Steps

- add authentication and authorization foundation
- define organization master data
- build first domain contexts for trainings and registrations
- introduce app shell pages for admin, coordinator, and participant flows
