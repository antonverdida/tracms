# TRACMS Login Government Portal Refresh

Date: July 23, 2026
Status: Planned for implementation

## Objective

Refine the TRACMS login page so it feels like an official DepEd Region IX enterprise portal instead of a general SaaS authentication screen.

## Design Direction

- Use a dedicated portal-style auth screen with no generic top header.
- Keep the visual structure close to the approved reference image:
  - information panel on the left
  - security banner and login card on the right
- Emphasize security, trust, government ownership, and simplicity.

## Functional Decisions

1. Keep password login as the visible sign-in method.
2. Remove magic-link login from the page UI.
3. Do not expose public self-registration from the login screen.
4. Do not add a fake forgot-password route.
5. Keep the existing backend auth routes intact for now.

## UI Decisions

- Left panel:
  - DepEd Region IX identity
  - TRACMS name and full system title
  - short centralized-platform description
  - four feature highlights
- Right panel:
  - secure access heading
  - smaller centered sign-in card
  - email and password fields
  - remember-me checkbox
  - government security notice
  - footer copyright text

## Content Rules

- Remove SaaS-style wording such as `Re-authenticate` and `Email-link access`.
- Use government-friendly copy such as `Welcome Back`, `Secure Access`, and `Authorized DepEd Region IX personnel only`.
- Keep support guidance truthful until password recovery and account request flows are implemented.
