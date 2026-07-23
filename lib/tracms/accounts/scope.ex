defmodule Tracms.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Tracms.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use in authorization checks,
  or to ensure specific code paths can only be accessed for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Tracms.Accounts.User

  defstruct user: nil, role_key: nil, office_id: nil, division_id: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{
      user: user,
      role_key: role_key_for(user),
      office_id: user.office_id,
      division_id: division_id_for(user)
    }
  end

  def for_user(nil), do: nil

  def role?(%__MODULE__{role_key: role_key}, expected_role) when is_binary(expected_role) do
    role_key == expected_role
  end

  def role?(_, _), do: false

  def system_admin?(scope), do: role?(scope, "regional_admin")
  def regional_admin?(scope), do: role?(scope, "regional_admin")
  def division_admin?(scope), do: role?(scope, "division_admin")
  def coordinator?(scope), do: role?(scope, "training_coordinator")

  defp role_key_for(%User{role: role}) do
    if Ecto.assoc_loaded?(role) && role do
      role.key
    end
  end

  defp role_key_for(_user), do: nil

  defp division_id_for(%User{office: office}) do
    if Ecto.assoc_loaded?(office) && office do
      office.division_id
    end
  end

  defp division_id_for(_user), do: nil
end
