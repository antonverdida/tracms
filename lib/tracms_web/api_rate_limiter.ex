defmodule TracmsWeb.ApiRateLimiter do
  @moduledoc false

  use GenServer

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def check(remote_ip) do
    config = Application.get_env(:tracms, :public_api_rate_limit, [])
    limit = Keyword.get(config, :limit, 60)
    window_ms = Keyword.get(config, :window_ms, 60_000)
    bucket = System.system_time(:millisecond) |> div(window_ms)
    key = {format_ip(remote_ip), bucket}

    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})
    remaining = max(limit - count, 0)

    if count <= limit do
      {:allow, limit, remaining}
    else
      {:deny, limit, window_ms - rem(System.system_time(:millisecond), window_ms)}
    end
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}, :hibernate}
  end

  @impl true
  def handle_info(:cleanup, state) do
    config = Application.get_env(:tracms, :public_api_rate_limit, [])
    window_ms = Keyword.get(config, :window_ms, 60_000)
    current_bucket = System.system_time(:millisecond) |> div(window_ms)

    for {{_ip, bucket} = key, _count} <- :ets.tab2list(@table), bucket < current_bucket - 1 do
      :ets.delete(@table, key)
    end

    schedule_cleanup()
    {:noreply, state, :hibernate}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(5))

  defp format_ip(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end
