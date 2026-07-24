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
end
