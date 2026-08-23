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
    today = Date.utc_today()

    attrs =
      Enum.into(attrs, %{
        title: "Training #{System.unique_integer([:positive])}",
        description: "Focused capability-building activity for schools and offices.",
        category: "Teacher Development",
        training_type: "Capacity Building Training",
        organizer: "DepEd Region IX",
        modality: :face_to_face,
        venue: "Regional Learning Center",
        venue_address: "Pagadian City, Zamboanga del Sur",
        resource_speaker: "Regional Learning and Development Team",
        total_hours: 24,
        start_time: ~T[08:00:00],
        end_time: ~T[17:00:00],
        objectives: "Strengthen core competencies and deliver practical school-based outputs.",
        target_participants: "Teachers, school heads, and DepEd personnel.",
        participant_qualification: "Must be endorsed by the appropriate office or school head.",
        registration_opens_on: Date.add(today, -5),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
        max_capacity: 120,
        starts_on: Date.add(today, 14),
        ends_on: Date.add(today, 16),
        attendance_monitoring_method: "QR Code and Manual Verification",
        certificate_type: "Certificate of Participation"
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

  def completed_training_fixture_for_manager(scope, attrs \\ %{}) do
    training_activity_fixture(
      scope,
      %{
        status: :completed,
        registration_opens_on: ~D[2026-06-20],
        registration_deadline: ~U[2026-07-05 09:00:00Z],
        starts_on: ~D[2026-07-10],
        ends_on: ~D[2026-07-12]
      }
      |> Map.merge(Enum.into(attrs, %{}))
    )
  end
end
