defmodule Mix.Tasks.Tracms.Schema.Health do
  use Mix.Task

  alias Tracms.SchemaHealth

  @shortdoc "Checks critical TRACMS tables and columns for schema drift"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    report = SchemaHealth.check()

    case report.status do
      :ok ->
        Mix.shell().info("""
        Schema health check passed for #{Mix.env()}.
        Checked #{report.checked_tables} critical tables and #{report.checked_columns} required columns.
        """)

      :error ->
        Mix.shell().error("""
        Schema health check failed for #{Mix.env()}.
        Checked #{report.checked_tables} critical tables and #{report.checked_columns} required columns.
        """)

        if report.missing_tables != [] do
          Mix.shell().error("Missing tables:")

          Enum.each(report.missing_tables, fn table_name ->
            Mix.shell().error("  - #{table_name}")
          end)
        end

        if report.missing_columns != %{} do
          Mix.shell().error("Missing columns:")

          Enum.each(report.missing_columns, fn {table_name, columns} ->
            Mix.shell().error("  - #{table_name}: #{Enum.join(columns, ", ")}")
          end)
        end

        Mix.raise("TRACMS schema health check failed.")
    end
  end
end
