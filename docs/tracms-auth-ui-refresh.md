# TRACMS Auth UI Refresh

Date: July 23, 2026
Status: Planned and ready for implementation

## Objective

Refresh the TRACMS login experience so it feels simple, professional, and government-ready while keeping the existing Phoenix authentication flow intact.

## Design Direction

- Use a minimal public header with fewer unauthenticated actions.
- Introduce a dedicated login presentation instead of reusing the generic page shell.
- Add a project logo and reuse it in the global header and login experience.
- Keep password sign-in as the primary action and move magic-link login into a secondary flow.
- Preserve one consistent button, panel, form, and flash style across the page.

## Reference Cues

- Microsoft sign-in flow emphasizes a very direct sequence: identity first, then password, with clear recovery support.
- Atlassian’s sign-in guidance reinforces a practical secondary path like email continuation and a simple “remember me” option.
- Microsoft 365 branding guidance highlights three high-value custom areas on sign-in surfaces: a branded illustration/background, a banner logo, and short supporting text.

## Planned Changes

1. Create a reusable branded header experience for public and authenticated states.
2. Remove the extra public auth strip and reduce unused unauthenticated header actions.
3. Add a dedicated TRACMS SVG logo asset.
4. Redesign the login page into a split professional auth layout:
   - left brand panel for project identity and trust cues
   - right sign-in card for the actual authentication controls
5. Simplify password login to one primary button plus a remember-me checkbox.
6. Keep email-link login available as a secondary recovery-style path.
7. Update login tests to match the revised wording and navigation.

## Guardrails

- Do not change backend authentication behavior beyond form simplification.
- Do not remove magic-link support.
- Keep the interface responsive and readable on small screens.
- Keep colors and typography aligned with the existing TRACMS design tokens.
