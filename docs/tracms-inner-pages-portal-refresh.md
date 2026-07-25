# TRACMS Inner Pages Portal Refresh

## Goal

Apply the same portal design discipline used on the dashboard to the main authenticated inner pages:

- Training Management
- Registration
- My Records

## Implemented Pages

### Training Management

- Added a clearer portal page header
- Added summary cards for key training status counts
- Reworked the managed trainings list into a denser operations table

### Registration

- Added a cleaner page header and catalog summary strip
- Reworked the open trainings view into structured registration cards
- Standardized training facts, badges, and primary actions

### My Records

- Added summary cards for total, approved, awaiting, and evaluation-pending records
- Reworked the registrations table for clearer status and action handling
- Kept evaluation and withdrawal actions visible without making the page feel crowded

## UI Direction

- Keep the authenticated experience visually consistent with the dashboard
- Use concise copy
- Prefer operational tables and compact cards over generic content blocks
- Maintain uniform panel spacing, badges, and action treatments

## Result

The primary authenticated pages now feel more like one connected portal instead of separate admin screens with different design language.

## Shared Component Pass

To keep the next implementation steps accurate and uniform, the repeated portal UI patterns were extracted into shared web components and helpers:

- portal page header
- portal stat grid and stat card
- portal empty state
- portal panel header
- shared portal formatting helpers for dates, datetimes, modalities, and summary card maps

This keeps the current Training Management, Registration, and My Records pages visually aligned while making the next module implementations easier to keep consistent.
