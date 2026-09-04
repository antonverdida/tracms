# TRACMS UI/UX Design

## Decision

TRACMS will use a responsive, LiveView-first government-service portal. The visual
language is calm, formal, and task-oriented: it should help Regional Office staff
find and complete training operations quickly without looking dense or ornamental.

The application will continue using Tailwind CSS v4 with semantic CSS tokens and
Phoenix function components. Bootstrap will not be added. It would duplicate the
existing Tailwind bundle and component API, increase CSS conflicts, and make the
interface less consistent. The reusable primitives below provide the same practical
benefit of a Bootstrap design system while following the established Phoenix stack.

## Application Shell

### Overall layout

- Use `Layouts.app` for every LiveView and pass `flash` and `current_scope`.
- Public and authentication pages use a focused, centered layout with minimal
  navigation.
- Authenticated operational pages use the dashboard shell: identity and account
  controls in the header, persistent primary navigation, then a constrained content
  area.
- Each page follows the same order: page header, short purpose statement, contextual
  actions, primary content, then optional secondary details.
- Keep a readable desktop content width and use one-column layouts for forms and
  narrow screens.

### Navigation, header, and sidebar

- The dashboard header displays the TRACMS/DepEd Region IX identity and the account
  menu. It remains visible while users work through long pages.
- The primary navigation exposes Dashboard, Training Management, Registrations,
  Attendance, Certificates, Reports, and Settings. Show the active section clearly.
- Desktop navigation is a horizontal dashboard menu. On small screens it becomes a
  horizontally scrollable menu rather than an overloaded sidebar or a hidden
  multi-level menu.
- Training subsections use the existing workspace navigation directly below the page
  heading; this keeps local tasks close to their parent feature.
- Role-restricted destinations must be omitted or disabled only when the role model
  calls for it; authorization remains enforced by the router and context layer, not
  by navigation visibility.

## Page Patterns

### Dashboard

- Start with operational KPIs: upcoming trainings, registration volume, attendance,
  certificates, and items requiring attention.
- Follow with actionable lists such as upcoming activities and recent work; charts
  are secondary and must answer a concrete operational question.
- Use a stronger onboarding empty state only for the primary dashboard panel. Other
  empty panels remain compact and neutral so an empty dashboard does not dominate the
  screen.

### Buttons and links

- Use `<.button>` variants: `primary` for the one main action, `secondary` for a
  supporting action, `ghost` for quiet or navigational actions, and `danger` only for
  destructive actions.
- Labels begin with a verb and describe the outcome, such as `Create training` or
  `Export attendance`.
- Every interactive control has a visible focus style, a minimum 44px target where
  practical, a disabled/loading state, and no color-only meaning.

### Forms

- Use `to_form/2`, `<.form>`, and the shared `<.input>` component. Forms are
  vertically arranged by default, with labels above controls and help text placed
  close to the relevant field.
- Validate on input only when feedback is useful; always validate on submit.
- Display field errors next to the field, preserve entered values, and move focus to
  the first invalid control after a failed submission when the interaction requires
  it.
- Group long forms into logical sections on a page. Use modals only for short,
  focused edits or confirmations.

### Tables

- Use `<.data_table>` for operational lists. Tables need a stable ID, concise column
  labels, semantic status badges, an accessible action column, and responsive
  overflow rather than clipped data.
- Place filtering, search, and export actions above the table. Keep row actions
  predictable across features.
- Every table implements loading and empty states. If data cannot be loaded, replace
  the table with an actionable error state rather than showing stale or blank rows.

### Modals, alerts, and states

- Use `<.modal>` for confirmations, short decisions, and focused tasks. It supports
  Escape and backdrop dismissal, an accessible dialog label, and a clear close
  control. Destructive confirmations name the affected record and use a `danger`
  primary action.
- Use layout flash messages for completed actions and shared `<.alert>` blocks for
  persistent contextual messages. Messages state what happened and what the user can
  do next.
- Empty states explain the absence of data and offer one relevant next step where the
  user has permission to act.
- Loading states use `<.loading>` or the table loading slot, preserve layout space,
  and expose status to assistive technology.
- Error states explain the failed action in plain language, retain user input when
  possible, and provide retry or recovery actions. Never expose internal exceptions.

## Visual System

### Color

Use semantic tokens from `assets/css/theme.css` and the compatible `--tracms-*`
tokens in `assets/css/app.css`:

| Role | Token | Use |
| --- | --- | --- |
| Primary | `--primary` / `--tracms-primary` | Navigation, primary actions, links |
| Secondary | `--secondary` | Supporting emphasis |
| Success | `--success` / `--tracms-success` | Completed and valid states |
| Warning | `--warning` / `--tracms-warning` | Attention needed |
| Danger | `--danger` / `--tracms-danger` | Destructive and failed states |
| Surface | `--background`, `--surface` | Page and card layers |

Use color to reinforce text, icons, and labels; never as the only signal. New visual
roles require a named semantic token rather than an arbitrary template color.

### Typography and icons

- Use the existing Aptos/Segoe UI system font stack for clear, familiar institutional
  reading.
- Maintain a clear hierarchy: page title, section title, body copy, then muted
  metadata. Do not use text size alone to express relationships; use headings in
  sequence.
- Use the existing Heroicons through `<.icon>`. Icons clarify a label or status and
  are not a substitute for essential text.

### Spacing, surfaces, and component style

- Base spacing on 4px increments, with 16px as the standard internal component gap
  and 24px as the usual section gap.
- Use the established `sm`, `md`, and `lg` radii. Cards and panels use a light border
  with a restrained shadow; avoid heavy elevation and competing gradients.
- Use pill shapes for buttons, badges, and compact navigation controls. Preserve the
  shared panel, table, card, badge, alert, and modal treatments across every feature.
- Motion is brief and purposeful: hover/focus feedback, loading indicators, and
  small LiveView transitions. Respect `prefers-reduced-motion` when adding motion.

## Responsive and Accessible Baseline

- Design mobile first. At small widths, stack page actions, collapse multi-column
  card grids, permit table scrolling, and retain all actions without hover-only
  controls.
- Keep body text legible without zooming, avoid fixed-height content areas, and test
  at approximately 320px, 768px, and 1280px widths.
- Meet WCAG 2.2 AA contrast for text and actionable controls. Keyboard users can
  reach, operate, and visibly locate every control.
- Use semantic landmarks, heading hierarchy, labelled navigation, descriptive button
  names, and live regions for asynchronous feedback.
- Labels are required for form controls; placeholders never replace labels. Error
  text is associated with its field and status changes are announced without forcing
  unexpected focus changes.
- Modal workflows require an accessible name, Escape dismissal, a visible close
  affordance, and focus management before they are expanded beyond the current
  implementation.

## Component Contract

Use existing primitives before introducing page-specific markup:

| Need | Component or pattern |
| --- | --- |
| Application shell | `<Layouts.app>` |
| Page or panel heading | `<.portal_page_header>` / `<.portal_panel_header>` |
| KPI card | `<.portal_stat_grid>` / `<.portal_stat_card>` |
| General card | `<.card>` |
| Form field | `<.input field={@form[:field]}>` |
| Operational list | `<.data_table>` |
| Status | `<.badge>` |
| Contextual feedback | `<.alert>` or layout flash |
| Empty collection | `<.portal_empty_state>` |
| Loading feedback | `<.loading>` or a table loading slot |
| Focused interaction | `<.modal>` |

When a pattern is needed by two features, promote it to a shared component with
documented assigns and tests. Do not create a page-specific visual system.

## Delivery Order

1. Preserve and complete the shared shell, tokens, primitives, and state patterns.
2. Apply the system to the dashboard and highest-frequency training workflows.
3. Add page-level components only after the shared pattern proves insufficient.
4. Test each new screen with keyboard-only use, narrow viewport checks, and its
   loading, empty, validation, and failure paths.
