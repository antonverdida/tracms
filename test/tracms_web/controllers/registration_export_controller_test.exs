defmodule TracmsWeb.RegistrationExportControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "registration exports" do
    test "training manager can download registrations as excel", %{conn: conn} do
      %{manager: manager, training: training, participant: participant} =
        registration_export_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/registrations/export/excel?training_id=#{training.id}")

      html = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/vnd.ms-excel; charset=utf-8"]
      assert html =~ "TRACMS Registrations Export"
      assert html =~ participant.user.full_name
    end

    test "training manager can download registrations as pdf", %{conn: conn} do
      %{manager: manager, training: training} = registration_export_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/registrations/export/pdf?training_id=#{training.id}")

      pdf_binary = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/pdf; charset=utf-8"]
      assert String.starts_with?(pdf_binary, "%PDF")

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="tracms-registrations-#{Date.utc_today()}.pdf")
             ]
    end
  end

  defp registration_export_fixture do
    manager = training_manager_scope_fixture("training_coordinator")
    participant = participant_scope_fixture()
    training = published_training_fixture_for_manager(manager.scope)

    registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    %{
      manager: manager,
      participant: participant,
      training: training,
      registration: registration
    }
  end
end
