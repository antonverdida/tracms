# TRACMS Dashboard Remediation Plan

Date: July 23, 2026
Status: Implemented

## Purpose

Correct the dashboard panel implementation so it matches the intended TRACMS portal experience more accurately.

This plan is based on:

- the current browser-reviewed dashboard output
- the provided homepage/dashboard reference image
- the earlier dashboard portal refresh document

This document should guide the next implementation pass before additional UI changes are made.

## Current Problems Observed

### 1. Panel layout is not accurate enough

The current dashboard is close in theme, but the panel composition does not yet feel like the intended homepage layout.

Main issues:

- the panels read like separate cards instead of one coordinated portal dashboard
- the desktop arrangement is still too generic and not close enough to the target homepage structure
- some sections feel oversized vertically, especially in empty states
- the visual rhythm between cards is not yet balanced

### 2. Empty-state panels are overcompensating

The current empty-state version is more polished than before, but it still feels too heavy.

Main issues:

- too many large empty-state blocks create visual noise
- some empty states feel like feature promos instead of operational dashboard panels
- the page should still look professional even when all values are zero

### 3. Panel hierarchy is still weak

The intended dashboard should have a clear hierarchy:

1. greeting and date
2. summary cards
3. primary operational panels
4. secondary utility panels

Right now, several sections compete too equally for attention.

### 4. Some panel content is not the best fit for the homepage

The homepage should prioritize quick reading and operational awareness.

The current version still needs refinement in:

- what belongs on the homepage
- what should be shortened
- what should move into inner pages instead of staying on the dashboard

### 5. Navigation and shell need tighter discipline

The shell is improved, but the dashboard should feel more like a government operations portal and less like a collection of admin widgets.

Remaining concerns:

- top-level controls still need cleaner visual discipline
- homepage sections should align more tightly with the horizontal portal style
- the dashboard should feel more intentional even before real data exists

## Correct Target Direction

The dashboard should match this direction:

- simple
- professional
- government-appropriate
- operational
- horizontally structured
- visually balanced

It should resemble the reference homepage more in structure, while still staying honest to the modules already implemented in TRACMS.

## Recommended Dashboard Structure

### Header Shell

Keep:

- DepEd Region IX identity
- TRACMS Portal title
- profile summary
- settings and logout
- horizontal navigation

Refine:

- reduce visual competition between profile and action buttons
- keep the header compact
- ensure spacing feels deliberate and not crowded

### Row 1: Greeting + Date

Keep this row very simple:

- greeting
- one short supporting line
- date pill on the right

Rules:

- greeting should use a natural human name when available
- supporting copy should be shorter than the current version
- no extra hero treatment

### Row 2: Four Summary Cards

This row should stay, but card behavior must be standardized.

Rules:

- equal height
- equal internal spacing
- consistent icon block sizing
- short labels only
- one compact supporting line only

Recommended cards for managers:

- Total Trainings
- Participants or Registrations
- Live Activities
- Pending Actions

### Row 3: Main Dashboard Panels

This row needs the biggest correction.

Target desktop structure:

- left: Upcoming Training Activities
- center: Training Status Pipeline
- right: Registration Status

Rules:

- these three panels should feel like the main operational core
- each panel should have a consistent header pattern
- panel body density should be balanced
- avoid over-tall empty states

### Row 4: Secondary Dashboard Panels

Target desktop structure:

- left: Registration Monitoring
- center: Quick Actions
- right: Recent Activities

Rules:

- these are secondary panels, not equal to the row above
- quick actions should be more compact and cleaner
- recent activity should feel like a concise feed, not a filler block
- monitoring should look tabular and operational

### Footer

Keep the footer minimal:

- copyright
- version

No additional messaging is needed.

## Panel-by-Panel Correction Plan

### Upcoming Training Activities

Current problem:

- empty state is too dominant

Correction:

- keep this panel tall enough for real content
- when empty, show one short neutral empty message
- keep only one clear action

When data exists:

- show date badge
- title
- one or two metadata lines
- one action button or link

### Training Status Pipeline

Current problem:

- this panel is close, but still visually heavier than needed

Correction:

- shorten row spacing
- reduce progress-bar dominance
- make counts easier to scan
- keep the note area smaller and lighter

### Registration Status

Current problem:

- good direction, but cards inside cards make the section feel too bulky

Correction:

- simplify each status row
- reduce internal padding
- use cleaner list styling rather than large mini-panels

### Registration Monitoring

Current problem:

- empty state is too generic
- the panel does not yet anchor the lower row strongly

Correction:

- keep this as a proper table-style operations panel
- use a smaller empty state
- prioritize a professional tabular appearance

### Quick Actions

Current problem:

- tiles are still too descriptive
- panel feels more like a landing page than an operations dashboard

Correction:

- reduce wording
- make actions more compact
- keep labels short
- use smaller helper text

### Recent Activities

Current problem:

- empty state still feels like filler

Correction:

- make this panel lighter and denser
- use a more compact list/feed style
- if empty, use one quiet message without oversized treatment

## Empty-State Strategy

The biggest design rule for the next pass:

Do not make every empty state a featured visual block.

Instead:

- only one panel may have a stronger onboarding-style empty state
- all other empty states should be short, quiet, and operational
- the page should still look balanced even when every count is zero

## Content Reduction Rules

To improve accuracy and professionalism:

- reduce repeated explanatory text
- avoid long descriptive paragraphs inside dashboard panels
- avoid more than one supporting sentence per panel section
- avoid multiple competing action buttons inside the same empty state unless clearly necessary

## Layout Rules For The Next Implementation

### Desktop

Use a 12-column layout with intentional spans.

Recommended:

- summary cards: 4 equal columns
- row 3: 4 / 4 / 4 or 5 / 4 / 3 depending on visual balance
- row 4: 5 / 3 / 4 or similar proportion

### Tablet

- collapse to 2 columns
- maintain panel priority order

### Mobile

- single-column stack
- keep panel padding tighter
- keep headers short

## Component Rules

The next implementation should normalize:

- panel header
- panel title
- panel action link
- empty-state message
- metric card icon block
- status row
- action tile
- activity item

No panel should invent its own spacing rules independently.

## Files Expected To Change In The Next Pass

- `lib/tracms_web/controllers/page_html/dashboard.html.heex`
- `lib/tracms_web/controllers/page_controller.ex`
- `lib/tracms_web/components/layouts.ex`
- `assets/css/app.css`
- `docs/tracms-dashboard-portal-refresh.md`

## Implementation Sequence

### Phase 1

Fix layout structure only:

- header cleanup
- dashboard row structure
- panel span corrections

### Phase 2

Simplify panel internals:

- reduce oversized empty states
- tighten text
- normalize spacing

### Phase 3

Refine data presentation:

- improve list density
- improve table appearance
- improve status row readability

### Phase 4

Final responsive pass:

- desktop balance
- tablet collapse
- mobile spacing

## Acceptance Criteria

The dashboard pass will be considered correct when:

1. The desktop dashboard clearly matches the intended reference structure.
2. Empty-state panels no longer feel oversized or promotional.
3. The homepage remains useful even with zero records.
4. The header, summary cards, and lower panels feel visually unified.
5. The page looks like a professional government portal, not a generic admin UI.

## Result

The remediation pass was implemented with these outcomes:

- the dashboard now follows a clearer two-row panel hierarchy
- the main operational row is more accurate to the intended homepage structure
- only the primary upcoming panel keeps a stronger empty-state treatment
- registration status now reads more like an operational list and less like nested cards
- lower-row utility panels are more compact and less promotional
