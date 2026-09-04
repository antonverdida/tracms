# TRACMS Coding Standards

## UI

- Prefer shared Phoenix function components over custom page markup.
- Use semantic design tokens, not arbitrary colors.
- Provide loading, empty, success, and failure states.
- Maintain responsive layouts and keyboard-accessible controls.

## LiveView

- Begin templates with `Layouts.app` and pass `current_scope`.
- Use `to_form/2`, `<.form>`, and `<.input>`.
- Add unique IDs for forms, actions, tables, and modals.
- Keep authorization in router scopes and contexts.

## Verification

- Test component outcomes using stable selectors.
- Run `mix precommit` after code changes.
