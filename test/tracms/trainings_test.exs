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
                 objectives: "Understand regional assessment planning and classroom application.",
                 category: "Education Technology Innovation",
                 training_type: "Custom Professional Learning Program",
                 organizer: "DepEd Region IX",
                 modality: :hybrid,
                 venue: "Pagadian City",
                 venue_address: "Pagadian City, Zamboanga del Sur",
                 resource_speaker: "Regional ICT Team",
                 total_hours: 16,
                 start_time: ~T[08:00:00],
                 end_time: ~T[17:00:00],
                 target_participants: "Teachers and supervisors",
                 participant_qualification: "Must be a current DepEd employee.",
                 registration_opens_on: ~D[2026-08-20],
                 registration_deadline: ~U[2026-09-01 08:00:00Z],
                 max_capacity: 80,
                 starts_on: ~D[2026-09-10],
                 ends_on: ~D[2026-09-11],
                 attendance_monitoring_method: "Manual Verification",
                 certificate_type: "Certificate of Participation",
                 registration_form_url: "https://forms.gle/deped-registration",
                 attendance_form_url: "https://forms.gle/deped-attendance"
               })

      assert training_activity.creator_user_id == user.id
      assert training_activity.office_id == office.id
      assert training_activity.division_id == office.division_id
      assert training_activity.status == :draft
      assert training_activity.resource_speaker == "Regional ICT Team"
      assert training_activity.category == "Education Technology Innovation"
      assert training_activity.training_type == "Custom Professional Learning Program"
      assert training_activity.registration_form_url == "https://forms.gle/deped-registration"
      assert training_activity.attendance_form_url == "https://forms.gle/deped-attendance"

      assert [approval_entry] = Trainings.list_training_approvals(scope, training_activity.id)
      assert approval_entry.action == :created
      assert approval_entry.from_status == nil
      assert approval_entry.to_status == :draft
      assert approval_entry.actor_role_key == scope.role_key
      assert approval_entry.acted_by_user_id == user.id
    end

    test "create_training_activity/2 allows an unscheduled training record" do
      %{scope: scope} = training_manager_scope_fixture()

      assert {:ok, %TrainingActivity{} = training_activity} =
               Trainings.create_training_activity(scope, %{
                 title: "Future Training Record",
                 description: "Details will be finalized after planning.",
                 objectives: "Confirm the final program requirements.",
                 category: "Teacher Development",
                 training_type: "Capacity Building Training",
                 organizer: "DepEd Region IX",
                 modality: :online,
                 venue: "To be confirmed",
                 venue_address: "To be confirmed",
                 target_participants: "Teachers",
                 participant_qualification: "To be confirmed",
                 attendance_monitoring_method: "Manual Verification",
                 certificate_type: "Certificate of Participation"
               })

      assert is_nil(training_activity.starts_on)
      assert is_nil(training_activity.ends_on)
      assert is_nil(training_activity.total_hours)
      assert is_nil(training_activity.start_time)
      assert is_nil(training_activity.end_time)
      assert is_nil(training_activity.max_capacity)
      assert is_nil(training_activity.registration_opens_on)
      assert is_nil(training_activity.registration_deadline)
    end

    test "create_training_activity/2 accepts custom categories and training types" do
      %{scope: scope} = training_manager_scope_fixture()

      training_activity =
        training_activity_fixture(scope, %{
          category: "Disaster Preparedness",
          training_type: "Community Learning Session"
        })

      assert training_activity.category == "Disaster Preparedness"
      assert training_activity.training_type == "Community Learning Session"
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

      assert approval_entries =
               Trainings.list_training_approvals(regional_scope, training_activity.id)

      assert Enum.map(approval_entries, & &1.action) == [
               :created,
               :submitted_to_division,
               :advanced_to_region_approval,
               :published
             ]

      assert Enum.map(approval_entries, & &1.to_status) == [
               :draft,
               :pending_division_approval,
               :pending_region_approval,
               :published
             ]
    end

    test "return_training_activity_for_revision/3 sends an approval-stage training back to draft with a note" do
      %{scope: coordinator_scope, office: office} =
        training_manager_scope_fixture("training_coordinator")

      training_activity = training_activity_fixture(coordinator_scope)

      assert {:ok, training_activity} =
               Trainings.advance_training_activity(coordinator_scope, training_activity)

      %{scope: division_scope} = training_manager_scope_fixture("division_admin")
      division_scope = %{division_scope | division_id: office.division_id, office_id: office.id}

      assert {:ok, training_activity} =
               Trainings.return_training_activity_for_revision(
                 division_scope,
                 training_activity,
                 "Revise the venue details and participant qualification section."
               )

      assert training_activity.status == :draft

      approval_entries = Trainings.list_training_approvals(division_scope, training_activity.id)
      returned_entry = List.last(approval_entries)

      assert returned_entry.action == :returned_for_revision
      assert returned_entry.from_status == :pending_division_approval
      assert returned_entry.to_status == :draft

      assert returned_entry.notes ==
               "Revise the venue details and participant qualification section."
    end

    test "generate_google_form/3 creates and stores generated form details after publication" do
      %{scope: scope} = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second)
        })

      assert {:ok, training_activity} =
               Trainings.generate_google_form(scope, training_activity, :registration)

      assert training_activity.registration_form_id == "generated-registration-form"

      assert training_activity.registration_form_url ==
               "https://docs.google.com/forms/d/generated-registration-form/viewform"

      assert {:ok, training_activity} =
               Trainings.generate_google_form(scope, training_activity, :attendance)

      assert training_activity.attendance_form_id == "generated-attendance-form"

      assert training_activity.attendance_form_url ==
               "https://docs.google.com/forms/d/generated-attendance-form/viewform"
    end

    test "update_training_status/3 manages lifecycle actions for a training record" do
      %{scope: scope} = training_manager_scope_fixture("regional_admin")

      training_activity =
        training_activity_fixture(scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second)
        })

      assert {:ok, training_activity} =
               Trainings.update_training_status(scope, training_activity, :registration_closed)

      assert training_activity.status == :registration_closed

      assert {:ok, training_activity} =
               Trainings.update_training_status(scope, training_activity, :in_progress)

      assert training_activity.status == :in_progress

      assert {:ok, training_activity} =
               Trainings.update_training_status(scope, training_activity, :completed)

      assert training_activity.status == :completed

      assert {:ok, training_activity} =
               Trainings.update_training_status(scope, training_activity, :archived)

      assert training_activity.status == :archived
    end
  end
end
