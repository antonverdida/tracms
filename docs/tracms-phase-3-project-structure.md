# TRACMS Phase 3 Project Structure

## Purpose

Keep the repository organized around Phoenix conventions and TRACMS business domains.

## Recommended Structure

```text
tracms/
|-- assets/
|   |-- css/
|   `-- js/
|-- config/
|-- docs/
|-- lib/
|   |-- tracms/
|   |   |-- accounts/
|   |   |-- trainings/
|   |   |-- registrations/
|   |   |-- attendance/
|   |   |-- certificates/
|   |   `-- reports/
|   `-- tracms_web/
|       |-- components/
|       |-- controllers/
|       `-- live/
|-- priv/
|   `-- repo/
|-- test/
|-- README.md
`-- mix.exs
```

## Structural Rules

- Keep domain logic under `lib/tracms/`.
- Keep web-facing LiveViews, components, and controllers under `lib/tracms_web/`.
- Keep planning and architecture decisions in `docs/`.
- Prefer one module per file.

## Recommended Domain Boundaries

- `Tracms.Accounts`
- `Tracms.Trainings`
- `Tracms.Registrations`
- `Tracms.Attendance`
- `Tracms.Certificates`
- `Tracms.Reports`
- `Tracms.Notifications`
- `Tracms.Audit`

## Phase Exit Criteria

Phase 3 is complete when:

- all new features have an obvious home
- business logic is not leaking into LiveViews
- docs, schema files, and tests follow consistent naming
