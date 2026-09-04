# TRACMS Phase 8 Tailwind Design System

## Purpose

Create a consistent UI system that keeps the app polished as new LiveViews are added.

## Design Tokens

Suggested colors:

- primary: `#003B7A`
- success: `#16A34A`
- warning: `#F59E0B`
- danger: `#DC2626`

## Tailwind Guidance For This Repo

- keep the Tailwind v4 import pattern in `assets/css/app.css`
- do not introduce `@apply`
- do not add a legacy `tailwind.config.js` unless the project truly needs it
- prefer reusable component classes and semantic CSS variables

## Reusable UI Components

- button
- card
- table
- modal
- badge
- navbar
- sidebar

## Design Quality Checklist

- [ ] consistent spacing scale
- [ ] typography hierarchy
- [ ] hover and focus states
- [ ] loading and empty states
- [ ] responsive layouts
- [ ] accessible color contrast

## Suggested File Locations

- `assets/css/app.css`
- `lib/tracms_web/components/core_components.ex`
- `lib/tracms_web/components/layouts/`
- `lib/tracms_web/components/`

## Phase Exit Criteria

Phase 8 is complete when:

- core screens share a consistent visual language
- repeated layout and action patterns use reusable components
- mobile and desktop layouts both feel intentional
