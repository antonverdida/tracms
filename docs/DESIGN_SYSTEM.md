# TRACMS Universal Design System

## Purpose

TRACMS uses one accessible, formal, government-appropriate visual language. New screens extend shared components and semantic tokens; they do not introduce page-specific visual systems.

## Source Of Truth

- Tokens: `assets/css/theme.css` and `assets/css/app.css`
- Core primitives: `lib/tracms_web/components/core_components.ex`
- Portal patterns: `lib/tracms_web/components/portal_components.ex`
- Application shell: `lib/tracms_web/components/layouts.ex`
- Enforcement: `CODEX_RULES.md` and `AGENTS.md`

## Color Tokens

Use semantic CSS variables only: `--primary`, `--secondary`, `--success`, `--warning`, `--danger`, `--neutral`, `--background`, and `--surface`. Existing `--tracms-*` tokens remain the compatibility layer for the current portal.

Do not add arbitrary color values to templates. Extend `theme.css` with a named semantic token when a new role is genuinely needed.

## Component Architecture

The current modules are the stable public component API. New components should be extracted into the following target folders as they become reusable:

```text
lib/tracms_web/components/
|-- ui/
|-- buttons/button.ex
|-- cards/card.ex
|-- forms/input.ex
|-- forms/select.ex
|-- forms/textarea.ex
|-- modals/modal.ex
|-- tables/table.ex
|-- alerts/alert.ex
`-- layouts/{sidebar,navbar,footer}.ex
```

Do not move existing components solely to match this structure. Extract or relocate only when a component is shared and its callers can be migrated safely.

## Required Primitives

- Buttons: use `<.button>` with `primary`, `secondary`, `success`, `danger`, or `ghost` variants.
- Forms: use `<.form>` with `to_form/2` and shared `<.input>` components. Never add raw inputs when the shared input supports the control.
- Cards and panels: use portal stat cards, `<.portal_panel_header>`, and a shared panel treatment.
- Tables: use the shared table shell, stable IDs, empty states, and loading states.
- Badges: use status chips with semantic status colors.
- Alerts: use flash or shared alert components; success and failure messages must be clear and actionable.
- Modals: reserve for short, focused actions. Long forms belong on pages.
- Empty and loading states: every collection and asynchronous action needs one.

## Page Contract

Every operational page follows this order: page header, concise description, contextual actions, main content, and optional footer actions. Dashboards use KPI cards, operational tables, and recent activity before decorative charts.

## LiveView Contract

Use `Layouts.app` with `current_scope`, shared components, semantic tokens, unique DOM IDs, and server-side validation. Use streams for growing collections. Put business behavior in contexts, not templates.
