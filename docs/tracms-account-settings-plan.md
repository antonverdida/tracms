# TRACMS Account Settings Plan

## Goal

Make `/users/settings` simple, professional, and consistent with the TRACMS portal without adding controls that the backend does not fully support.

## Current Direction

The page already has the correct core purpose, but it still feels too busy because it includes repeated context, extra helper text, and leftover sections that are no longer part of the preferred design.

## Final Page Structure

Use one clean settings page with two main panels:

1. `Account Information`
2. `Certificate Layout`

## Section Details

### Account Information

Show and allow update of:

- `Full Name`
- `Employee ID`

Show as read-only context:

- `Office`
- `Division`
- `Current Email`

Keep the existing secure flows inside the same main panel:

- `Current Email`
- `Change Email`
- `Update Password`

This should be the main full-width panel so profile and security actions stay together and use less space.

### Certificate Layout

Keep this visible only for the system administrator role.

Show only the controls that matter:

- `Certificate Size`
- `Choose Photo`
- selected file name or saved file link
- `Save`

Remove extra preview-heavy presentation from the settings page so this area stays focused on configuration, not certificate viewing.

## Items To Remove Or Avoid

- notification summary panels
- recent account activity panels
- profile completion or readiness cards
- active session counters
- repeated office and division summaries
- long helper paragraphs that do not help the user complete an action

## Route Placement

Keep the page in the existing authenticated settings route:

- Route: `/users/settings`
- Pipeline: `[:browser, :require_authenticated_user]`
- Live Session: `:require_authenticated_user`

Why:

- this page manages personal account information
- it must remain available only to logged-in users
- email and password changes still rely on `on_mount {TracmsWeb.UserAuth, :require_sudo_mode}`

No route change is needed for this refresh.

## Implementation Notes

- keep the current portal header and panel system
- use the same button styling already used across the dashboard
- keep wording short and official
- avoid introducing tabs or extra cards unless there is a clear user need
- remove dead LiveView handlers for settings sections that are no longer rendered

## Expected Result

After this refresh, the settings page should feel:

- clean
- official
- easy to scan
- consistent with the rest of TRACMS
- concise government-style copy
- uniform TRACMS portal panel and button styling
