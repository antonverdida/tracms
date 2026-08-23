defmodule Tracms.Release do
  @moduledoc false

  def migrate do
    Application.load(:tracms)

    for repo <- Application.fetch_env!(:tracms, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end
end
