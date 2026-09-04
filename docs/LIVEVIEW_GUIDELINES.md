# TRACMS LiveView Guidelines

1. Check the component library before writing markup.
2. Use the existing authenticated `live_session` and router pipeline appropriate to the page.
3. Pass `@current_scope` to layouts and contexts; use `@current_scope.user` in templates.
4. Keep data loading and mutations in contexts.
5. Use LiveView streams for collections that can grow or refresh.
6. Provide a stable ID and test selector for every important interactive element.
7. Use `<.link navigate>` or `<.link patch>` and avoid deprecated redirects.
