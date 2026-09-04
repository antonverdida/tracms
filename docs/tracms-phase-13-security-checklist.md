# TRACMS Phase 13 Security Checklist

## Purpose

Confirm the application is safe to operate before broader rollout.

## Security Checklist

- [ ] CSRF protection enabled
- [ ] secure cookies configured
- [ ] password hashing enabled
- [ ] authorization checks enforced
- [ ] input validation applied
- [ ] rate limiting in place
- [ ] audit logs implemented

## TRACMS-Specific Review Points

- certificate verification endpoints expose only minimal public data
- attendance overrides are logged
- certificate reissues are logged
- report exports respect role permissions
- uploaded files and generated documents are access-controlled

## Operational Hardening

- enforce HTTPS in deployed environments
- keep secrets out of the repository
- review dependency updates regularly
- verify public endpoints for abuse and enumeration risk

## Phase Exit Criteria

Phase 13 is complete when:

- authentication and authorization are enforced consistently
- audit coverage exists for sensitive actions
- public-facing endpoints have explicit data exposure limits
