defmodule Tracms.RegistrationsTest do
  use Tracms.DataCase

  alias Tracms.Registrations

  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "participant registrations" do
    test "register_user_for_training/3 creates a registration for a published training" do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      assert {:ok, registration} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)

      assert registration.registrant_user_id == participant.user.id
      assert registration.training_activity_id == training_activity.id
      assert registration.status == :submitted
    end

    test "register_user_for_training/3 prevents duplicate registrations" do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      assert {:ok, _registration} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)

      assert {:error, :already_registered} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)
    end

    test "register_user_for_training/3 supports published trainings without schedule limits" do
      participant = participant_scope_fixture()
      %{scope: scope} = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_opens_on: nil,
          registration_deadline: nil,
          max_capacity: nil,
          starts_on: nil,
          ends_on: nil,
          total_hours: nil
        })

      assert {:ok, registration} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)

      assert registration.training_activity_id == training_activity.id
    end

    test "list_open_training_activities/1 excludes already registered trainings" do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      assert {:ok, _registration} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)

      refute Enum.any?(
               Registrations.list_open_training_activities(participant.scope),
               &(&1.id == training_activity.id)
             )
    end

    test "register_user_for_training/3 blocks registration before the opening date" do
      participant = participant_scope_fixture()
      manager = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_opens_on: Date.add(Date.utc_today(), 3),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day)
        })

      assert {:error, :registration_not_open} =
               Registrations.register_user_for_training(participant.scope, training_activity.id)
    end
  end

  describe "registration review" do
    test "review_registration/4 lets a training manager approve a registration" do
      registration = registration_fixture()
      manager = training_manager_scope_fixture("regional_admin")

      assert {:ok, reviewed} =
               Registrations.review_registration(
                 manager.scope,
                 registration,
                 :approved,
                 "Approved"
               )

      assert reviewed.status == :approved
      assert reviewed.reviewer_user_id == manager.user.id
      assert reviewed.review_notes == "Approved"
    end

    test "withdraw_registration/2 lets the registrant withdraw an active registration" do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      {:ok, registration} =
        Registrations.register_user_for_training(participant.scope, training_activity.id)

      assert {:ok, withdrawn} =
               Registrations.withdraw_registration(participant.scope, registration)

      assert withdrawn.status == :withdrawn
    end

    test "list_training_registrations/2 is limited to the training manager scope" do
      manager = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 3, :day)
        })

      participant = participant_scope_fixture()

      {:ok, registration} =
        Registrations.register_user_for_training(participant.scope, training_activity.id)

      assert [listed] =
               Registrations.list_training_registrations(manager.scope, training_activity.id)

      assert listed.id == registration.id
    end
  end

  describe "external registration intake" do
    test "create_external_registration_submission/3 marks a submission for follow-up when no account exists" do
      manager = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration"
        })

      assert {:ok, submission} =
               Registrations.create_external_registration_submission(
                 manager.scope,
                 training_activity.id,
                 %{
                   "full_name" => "Juan External",
                   "email" => "juan.external@example.com",
                   "employee_number" => "EMP-1001",
                   "office_name" => "Sample Office"
                 }
               )

      assert submission.status == :needs_account
      assert is_nil(submission.matched_user_id)
    end

    test "import_external_registration_submission/2 converts a matched external submission into a real registration" do
      manager = training_manager_scope_fixture("training_coordinator")
      participant = participant_scope_fixture()

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration"
        })

      assert {:ok, submission} =
               Registrations.create_external_registration_submission(
                 manager.scope,
                 training_activity.id,
                 %{
                   "full_name" => participant.user.full_name,
                   "email" => participant.user.email,
                   "employee_number" => participant.user.employee_number,
                   "office_name" => participant.office.name
                 }
               )

      assert submission.status == :pending_review

      assert {:ok, registration} =
               Registrations.import_external_registration_submission(manager.scope, submission)

      assert registration.training_activity_id == training_activity.id
      assert registration.registrant_user_id == participant.user.id
      assert registration.status == :submitted

      [reloaded_submission] =
        Registrations.list_external_registration_submissions(manager.scope, training_activity.id)

      assert reloaded_submission.status == :imported
      assert reloaded_submission.imported_registration_id == registration.id
    end

    test "bulk_import_external_registration_submissions/3 stages valid rows and reports row-level errors" do
      manager = training_manager_scope_fixture("training_coordinator")
      participant = participant_scope_fixture()

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration"
        })

      tabular_data = """
      full_name\temail\temployee_number\toffice_name
      #{participant.user.full_name}\t#{participant.user.email}\t#{participant.user.employee_number}\t#{participant.office.name}
      Missing Email\t\tEMP-404\tUnknown Office
      """

      assert {:ok, result} =
               Registrations.bulk_import_external_registration_submissions(
                 manager.scope,
                 training_activity.id,
                 %{"batch_reference" => "Google Sheet A", "tabular_data" => tabular_data}
               )

      assert result.created_count == 1
      assert result.skipped_count == 0
      assert result.error_count == 1
      assert [%{row: 3, message: message}] = result.errors
      assert message =~ "email can't be blank"

      [submission] =
        Registrations.list_external_registration_submissions(manager.scope, training_activity.id)

      assert submission.source_reference == "Google Sheet A row 2"
      assert submission.status == :pending_review
    end

    test "sync_external_registration_submissions_from_google_sheet/2 stages rows and skips duplicates on later syncs" do
      manager = training_manager_scope_fixture("training_coordinator")

      participant =
        participant_scope_fixture(%{
          email: "sync.participant@example.com",
          full_name: "Sync Participant",
          employee_number: "EMP-SYNC-1"
        })

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration",
          registration_sheet_id: "sync-sheet-main",
          registration_sheet_range: "Form Responses 1!A:F"
        })

      assert {:ok, first_result} =
               Registrations.sync_external_registration_submissions_from_google_sheet(
                 manager.scope,
                 training_activity.id
               )

      assert first_result.created_count == 1
      assert first_result.skipped_count == 0
      assert first_result.error_count == 1

      [submission] =
        Registrations.list_external_registration_submissions(manager.scope, training_activity.id)

      assert submission.matched_user_id == participant.user.id
      assert submission.source_reference == "response-001"

      assert {:ok, second_result} =
               Registrations.sync_external_registration_submissions_from_google_sheet(
                 manager.scope,
                 training_activity.id
               )

      assert second_result.created_count == 0
      assert second_result.skipped_count == 1
      assert second_result.error_count == 1
    end
  end
end
