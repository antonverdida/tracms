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

## Docker Setup

1. Install Docker Desktop.
2. Copy `.env.example` to `.env` and replace both placeholder values. Generate the
   `SECRET_KEY_BASE` value with `mix phx.gen.secret`.
3. Start the application and PostgreSQL:

   ```sh
   docker compose up --build
   ```

The application is available at [http://localhost:4000](http://localhost:4000). Docker runs
database migrations before starting the web server. PostgreSQL data and uploaded certificate
assets are stored in the persistent `postgres_data` and `uploads_data` Docker volumes.

## Production API

The public API is intentionally limited to certificate verification. It never exposes email
addresses, employee numbers, registrations, or administrative data.

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Container liveness check. |
| `GET /health/ready` | Readiness check, including PostgreSQL connectivity. |
| `GET /api/v1/certificates/verify/:verification_code` | Verify a QR-code token. |
| `GET /api/v1/certificates?certificate_number=...` | Verify by certificate number. |

Successful verification returns `200` with a `data.verification.status` of `valid`. Unknown
certificates return `404`, revoked certificates return `410`, and repeated verification attempts
are limited to 60 requests per IP each minute by default. Set `API_ALLOWED_ORIGINS` to the exact
origin of an official website only when it is hosted separately.

Before a public deployment, set `PHX_HOST` to the real domain, use `PHX_SCHEME=https`, set
`PHX_URL_PORT=443`, and provide strong, unique database and `SECRET_KEY_BASE` values through your
deployment secret manager. Use a URL-safe database password, such as the output of
`openssl rand -hex 32`.

## Gigalixir Deployment

This project includes Gigalixir's Elixir release buildpacks, pinned Elixir/Erlang/Node versions,
the Phoenix asset build hook, and a release Procfile that runs database migrations before the web
server starts. Deploy it with:

```sh
gigalixir create -n your-tracms-app
gigalixir pg:create
gigalixir config:set PHX_HOST=your-tracms-app.gigalixirapp.com PHX_SCHEME=https PHX_URL_PORT=443
gigalixir git:remote your-tracms-app
git push gigalixir main
```

Gigalixir provides `DATABASE_URL`, `PORT`, and `SECRET_KEY_BASE`. Configure `API_ALLOWED_ORIGINS`
when a separate official website calls the public API. The local `priv/static/uploads` directory
is not persistent on Gigalixir, so certificate layout uploads must be moved to object storage
before relying on them in production.

## Key Docs

- [Implementation plan](./docs/tracms-implementation-plan.md)
- [Phase 0 foundation](./docs/tracms-phase-0-foundation.md)
- [UI system](./docs/tracms-ui-system.md)

## Next Steps

- add authentication and authorization foundation
- define organization master data
- build first domain contexts for trainings and registrations
- introduce app shell pages for admin, coordinator, and participant flows
