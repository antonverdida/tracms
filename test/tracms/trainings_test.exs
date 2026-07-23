defmodule Tracms.TrainingsTest do
  use Tracms.DataCase

  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  import Tracms.TrainingsFixtures

  describe "training activities" do
    test "create_training_activity/2 sets creator and scope ownership" do
      %{scope: scope, user: user, office: office} = training_manager_scope_fixture()

      assert {:ok, %TrainingActivity{} = training_activity} =
               Trainings.create_training_activity(scope, %{
                 title: "Assessment Training",
                 description: "Training description",
                 category: "Assessment",
                 organizer: "DepEd Region IX",
                 modality: :hybrid,
                 venue: "Pagadian City",
                 registration_deadline: ~U[2026-09-01 08:00:00Z],
                 max_capacity: 80,
                 starts_on: ~D[2026-09-10],
                 ends_on: ~D[2026-09-11]
               })

      assert training_activity.creator_user_id == user.id
      assert training_activity.office_id == office.id
      assert training_activity.division_id == office.division_id
      assert training_activity.status == :draft
    end

    test "list_training_activities/1 restricts coordinator visibility to the assigned office" do
      %{scope: scope} = training_manager_scope_fixture("training_coordinator")
      %{scope: other_scope} = training_manager_scope_fixture("training_coordinator")

      visible = training_activity_fixture(scope, %{title: "Visible training"})
      _hidden = training_activity_fixture(other_scope, %{title: "Hidden training"})

      assert [result] = Trainings.list_training_activities(scope)
      assert result.id == visible.id
    end

    test "advance_training_activity/2 follows the approval path" do
      %{scope: coordinator_scope, office: office} =
        training_manager_scope_fixture("training_coordinator")

      training_activity = training_activity_fixture(coordinator_scope)

      assert {:ok, training_activity} =
               Trainings.advance_training_activity(coordinator_scope, training_activity)

      assert training_activity.status == :pending_division_approval

      %{scope: division_scope} = training_manager_scope_fixture("division_admin")

      division_scope = %{division_scope | division_id: office.division_id, office_id: office.id}

      assert {:ok, training_activity} =
               Trainings.advance_training_activity(division_scope, training_activity)

      assert training_activity.status == :pending_region_approval

      %{scope: regional_scope} = training_manager_scope_fixture("regional_admin")

      assert {:ok, training_activity} =
               Trainings.advance_training_activity(regional_scope, training_activity)

      assert training_activity.status == :published
      assert %DateTime{} = training_activity.published_at
    end
  end
end
