# TRACMS UI System

## Design Goal

TRACMS should look like a professional government information system:

- calm
- structured
- readable
- consistent
- accessible

## Visual Direction

- light interface by default
- neutral surfaces with DepEd-aligned blue accents
- restrained use of red for institutional emphasis
- soft depth, not heavy shadows
- strong typography hierarchy

## Component Standards

### Buttons

Supported variants in Phase 0:

- `primary`
- `secondary`
- `ghost`
- `danger`

Rules:

- use pill-shaped buttons consistently
- keep font weight strong
- keep hover movement subtle
- use visible keyboard focus states

### Panels

Rules:

- use one standard border treatment
- use one standard radius family
- use muted panels only for secondary sections
- prefer panels over visually disconnected floating elements

### Forms

Rules:

- vertical layout by default
- one label treatment
- one input treatment
- one error treatment
- no mixed styling between pages

### Tables

Rules:

- one table shell
- one header treatment
- one hover behavior
- one action cell pattern

### Flash Messages

Rules:

- fixed top-right placement
- one card layout
- clear visual difference between info and error states

## Modal Standard

Modal behavior is planned but not yet implemented.

When added, it should follow these rules:

- use only for short focused tasks
- keep sizes standardized as `sm`, `md`, and `lg`
- do not place large multi-section forms in modals
- always include clear primary and secondary actions

## Styling Source

The initial styles are currently defined in:

- `assets/css/app.css`
- `lib/tracms_web/components/core_components.ex`
- `lib/tracms_web/components/layouts.ex`

As the app grows, the same standard should be extended instead of creating isolated page-specific styles.
