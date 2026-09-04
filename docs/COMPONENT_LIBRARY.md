# TRACMS Component Library

## Available Components

| Need | Component or Pattern |
| --- | --- |
| Primary action | `<.button variant="primary">` |
| Secondary or back action | `<.button variant="secondary">` or `ghost` |
| Destructive action | `<.button variant="danger">` |
| Form field | `<.input field={@form[:field]}>` |
| Page heading | `<.portal_page_header>` |
| Panel heading | `<.portal_panel_header>` |
| KPI cards | `<.portal_stat_grid>` and `<.portal_stat_card>` |
| General content, statistics, or features | `<.card>` |
| Operational table | `<.data_table>` with empty and loading states |
| Focused confirmation or short action | `<.modal>` |
| Empty collection | `<.portal_empty_state>` |
| Flash feedback | `<.flash>` through `Layouts.app` |
| Icons | `<.icon name="hero-...">` |

## Extension Rule

Check this library before creating a page-level helper. If a pattern is used by two features, promote it to a component with documented assigns and tests.
