defmodule Tracms.TrainingsFixtures do
  @moduledoc """
  Test helpers for the Trainings context.
  """

  alias Tracms.Accounts
  alias Tracms.Accounts.Scope
  alias Tracms.Trainings

  import Tracms.AccountsFixtures
  import Tracms.OrganizationFixtures

  def training_activity_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Training #{System.unique_integer([:positive])}",
        description: "Focused capability-building activity for schools and offices.",
        category: "Professional Development",
        organizer: "DepEd Region IX",
        modality: :face_to_face,
        venue: "Regional Learning Center",
        registration_deadline: ~U[2026-08-01 09:00:00Z],
        max_capacity: 120,
        starts_on: ~D[2026-08-10],
        ends_on: ~D[2026-08-12]
      })

    {:ok, training_activity} = Trainings.create_training_activity(scope, attrs)
    training_activity
  end

  def training_manager_scope_fixture(role_key \\ "training_coordinator") do
    role = named_role_fixture(role_key)
    office = office_fixture()
    user = user_fixture()

    {:ok, user} =
      Accounts.update_user_profile(user, %{
        role_id: role.id,
        office_id: office.id,
        status: :active,
        full_name: "Manager #{System.unique_integer([:positive])}"
      })

    %{user: user, role: role, office: office, scope: Scope.for_user(user)}
  end
end
