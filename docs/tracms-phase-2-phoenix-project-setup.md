# TRACMS Phase 2 Phoenix Project Setup

## Purpose

Verify that the existing Phoenix application is configured correctly for continued feature development.

## Current Reality In This Repo

The application already exists, so this phase is about validation and completion, not creating a fresh `mix phx.new` scaffold.

## Setup Checklist

- [x] Phoenix project scaffolded
- [ ] PostgreSQL configuration reviewed
- [ ] Database created locally
- [ ] Migrations run locally
- [ ] Assets setup verified
- [ ] Precommit checks passing

## Reference Commands

Initial scaffold reference:

```sh
mix phx.new tracms
```

Current project commands:

```sh
mix deps.get
mix ecto.create
mix ecto.migrate
mix assets.setup
mix precommit
```

## PostgreSQL Configuration Example

Development configuration belongs in `config/dev.exs` or environment-backed runtime config, depending on deployment mode.

```elixir
config :tracms, Tracms.Repo,
  username: "postgres",
  password: "",
  database: "tracms_dev"
```

## Notes For This Codebase

- Keep using PostgreSQL as the primary datastore.
- Prefer environment-backed secrets for deployed environments.
- Use `mix precommit` as the final quality gate after code changes.
- Tailwind setup in Phoenix 1.8 does not require a legacy `tailwind.config.js` by default.

## Phase Exit Criteria

Phase 2 is complete when:

- local database setup works from a clean checkout
- migrations run without manual fixes
- assets install and build cleanly
- `mix precommit` passes
