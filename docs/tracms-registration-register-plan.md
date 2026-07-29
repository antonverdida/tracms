# TRACMS Registration Register Plan

## Goal

Make the registration register page simple, professional, and easy to scan for training managers.

## Route

- `/registrations/trainings/:training_id`

## Design Direction

- Keep the page focused on participant names only
- Remove extra controls, approval actions, and excess wording
- Match the clean management style already used in the certificates module

## Recommended Layout

### Page Header

- Eyebrow: `Registrations`
- Title: training title
- Short copy: `Review the registered participants for this training.`
- Action: `Back to registrations`

### Training Context Row

Use one compact row of three context cards:

- `Start Date`
- `End Date`
- `Total Participants`

This provides quick context without turning the page into a dashboard.

### Main Panel

- Panel title: `Participant List`
- Right-side action: participant name search
- No extra subtitle unless it helps navigation

### Participant Table

Keep the table minimal:

- `No.`
- `Participant Name`

Do not show:

- email addresses
- registration status
- approval buttons
- review notes
- extra management actions

## Empty State

- `No participants registered yet.`

## Implementation Rule

This page should stay as a clean viewing register.

If detailed approval or review workflows are needed, keep them in the existing manager workflow route instead of expanding this page.
