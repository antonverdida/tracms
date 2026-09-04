# TRACMS Phase 7 LiveView Development

## Purpose

Build the main application experience with Phoenix LiveView instead of a heavy client-side JavaScript app.

## Planned LiveViews

- `DashboardLive`
- `TrainingLive`
- `RegistrationLive`
- `AttendanceLive`
- `CertificateLive`
- `ReportsLive`
- `SettingsLive`

## Feature Checklist

- [ ] Live navigation
- [ ] Forms
- [ ] Validation
- [ ] Tables
- [ ] Modals
- [ ] Search
- [ ] Pagination
- [ ] Filters

## Implementation Rules

- Wrap LiveView templates with `Layouts.app`.
- Use `to_form/2` and the shared `<.input>` component for forms.
- Use streams for growing collections.
- Keep business logic in contexts and keep LiveViews focused on UI state.
- Add stable DOM ids to forms, buttons, tables, and modals to support tests.

## Recommended Build Order

1. `DashboardLive`
2. `TrainingLive`
3. `RegistrationLive`
4. `AttendanceLive`
5. `CertificateLive`
6. `ReportsLive`
7. `SettingsLive`

## Testing Checklist

- [ ] LiveView mount tests
- [ ] form submit tests
- [ ] filter and pagination tests
- [ ] authorization-aware UI tests
- [ ] empty-state tests

## Phase Exit Criteria

Phase 7 is complete when:

- each core module has an initial LiveView
- forms validate server-side
- tables, filters, and navigation work without custom frontend complexity
