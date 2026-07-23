defmodule Tracms.Repo do
  use Ecto.Repo,
    otp_app: :tracms,
    adapter: Ecto.Adapters.Postgres
end
