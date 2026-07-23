defmodule Tracms.RegistrationsFixtures do
  @moduledoc """
  Test helpers for the Registrations context.
  """

  alias Tracms.Accounts
  alias Tracms.Accounts.Scope
  alias Tracms.Registrations

  import Tracms.AccountsFixtures
  import Tracms.OrganizationFixtures
  import Tracms.TrainingsFixtures

  def participant_scope_fixture do
    role = named_role_fixture("participant")
    office = office_fixture()
    user = user_fixture()

    {:ok, user} =
      Accounts.update_user_profile(user, %{
        role_id: role.id,
        office_id: office.id,
        status: :active,
        full_name: "Participant #{System.unique_integer([:positive])}"
      })

    %{user: user, role: role, office: office, scope: Scope.for_user(user)}
  end

  def published_training_fixture do
    %{scope: scope} = training_manager_scope_fixture("training_coordinator")

    training_activity_fixture(scope, %{
      status: :published,
      published_at: DateTime.utc_now(:second),
      registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
      starts_on: Date.add(Date.utc_today(), 14),
      ends_on: Date.add(Date.utc_today(), 16)
    })
  end

  def registration_fixture(attrs \\ %{}) do
    participant = Map.get_lazy(attrs, :participant, fn -> participant_scope_fixture() end)

    training_activity =
      Map.get_lazy(attrs, :training_activity, fn -> published_training_fixture() end)

    {:ok, registration} =
      Registrations.register_user_for_training(
        participant.scope,
        training_activity.id,
        Map.get(attrs, :registration_attrs, %{})
      )

    registration
  end
end
