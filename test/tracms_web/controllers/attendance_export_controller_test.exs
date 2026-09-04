defmodule TracmsWeb.AttendanceExportControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance

  describe "attendance exports" do
    test "training manager can download attendance as excel", %{conn: conn} do
      %{manager: manager, training: training} = attendance_export_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/attendance/export/excel?training_id=#{training.id}")

      html = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/vnd.ms-excel; charset=utf-8"]
      assert html =~ "TRACMS Attendance Export"
    end

    test "training manager can download attendance as pdf", %{conn: conn} do
      %{manager: manager, training: training} = attendance_export_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/attendance/export/pdf?training_id=#{training.id}")

      pdf_binary = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/pdf; charset=utf-8"]
      assert String.starts_with?(pdf_binary, "%PDF")

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="tracms-attendance-#{Date.utc_today()}.pdf")
             ]
    end
  end

  defp attendance_export_fixture do
    manager = training_manager_scope_fixture("training_coordinator")
    participant = participant_scope_fixture()
    training = published_training_fixture_for_manager(manager.scope)

    registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    attendance_session =
      attendance_session_fixture(
        training_manager: manager,
        training_activity: training
      )

    {:ok, attendance_session} = Attendance.open_session(manager.scope, attendance_session)

    {:ok, _attendance_record} =
      Attendance.mark_attendance(manager.scope, attendance_session.id, registration.id, %{
        status: :present
      })

    %{
      manager: manager,
      participant: participant,
      training: training,
      registration: registration,
      attendance_session: attendance_session
    }
  end
end
