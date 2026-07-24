defmodule Mix.Tasks.Tracms.Schema.HealthTest do
  use Tracms.DataCase, async: false

  import ExUnit.CaptureIO

  test "prints a success summary for a healthy schema" do
    Mix.Task.reenable("tracms.schema.health")

    output =
      capture_io(fn ->
        Mix.Task.run("tracms.schema.health")
      end)

    assert output =~ "Schema health check passed for test."
    assert output =~ "critical tables"
    assert output =~ "required columns"
  end
end
