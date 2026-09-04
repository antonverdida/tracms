# TRACMS Phase 5 Authentication

## Purpose

Establish secure account access using Phoenix authentication conventions that match this codebase.

## Recommended Generator

```sh
mix phx.gen.auth Accounts User users
```

## Authentication Checklist

- [ ] Login
- [ ] Logout
- [ ] Registration
- [ ] Password reset
- [ ] Email confirmation
- [ ] Session security

## Phoenix Routing Guidance

Use the existing generated auth structure:

- place routes that require login inside the existing `live_session :require_authenticated_user`
- place routes that work with or without login inside the existing `live_session :current_user`
- pass `current_scope` into `Layouts.app`
- use `@current_scope.user` in templates instead of `@current_user`

Why:

- Phoenix 1.8 auth scaffolding assigns `current_scope`
- router-level auth keeps redirects and session behavior predictable
- LiveViews stay consistent with the generated security model

## TRACMS-Specific Authentication Needs

- staff accounts for administrative and training management actions
- optional participant accounts if self-service history or certificate access expands later
- explicit session timeout and secure cookie settings in deployed environments

## Phase Exit Criteria

Phase 5 is complete when:

- auth pages and sessions work end to end
- protected routes correctly redirect unauthenticated users
- authenticated LiveViews render with `current_scope`
