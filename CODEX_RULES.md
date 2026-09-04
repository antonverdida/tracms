# TRACMS Codex Rules

These rules supplement `AGENTS.md`; if they conflict, `AGENTS.md` takes precedence.

1. Read `docs/DESIGN_SYSTEM.md` before implementing a UI feature.
2. Check `docs/COMPONENT_LIBRARY.md` before creating markup or a new component.
3. Never create custom buttons, raw inputs, arbitrary card styles, or random color values when a shared component or semantic token exists.
4. Use shared components for buttons, forms, panels, tables, badges, alerts, empty states, and loading states.
5. Extend a reusable component before duplicating a UI pattern across pages.
6. Use `Layouts.app`, `current_scope`, router-level authorization, `to_form/2`, and stable DOM IDs in LiveViews.
7. Follow `docs/LIVEVIEW_GUIDELINES.md` and run `mix precommit` after code changes.

## UI Workflow

1. Check existing components.
2. Extend a component if needed.
3. Build the LiveView or controller view.
4. Connect the context with scoped authorization.
5. Add focused tests.
6. Run `mix precommit`.
