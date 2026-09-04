defmodule TracmsWeb.PageController do
  use TracmsWeb, :controller

  import Ecto.Query

  alias Tracms.Accounts.Scope
  alias Tracms.Attendance.AttendanceRecord
  alias Tracms.Certificates
  alias Tracms.Registrations
  alias Tracms.Repo
  alias Tracms.Trainings
  alias TracmsWeb.DashboardGreeting

  def dashboard(conn, _params) do
    scope = conn.assigns.current_scope
    today = Date.utc_today()

    if Scope.training_manager?(scope) do
      managed_trainings = Trainings.list_training_activities(scope)
      manageable_registrations = Registrations.list_manageable_registrations(scope)
      manageable_certificates = Certificates.list_manageable_certificates(scope)

      assigns =
        common_dashboard_assigns(scope, today)
        |> Map.merge(
          manager_dashboard_assigns(
            today,
            managed_trainings,
            manageable_registrations,
            manageable_certificates
          )
        )

      render(conn, :dashboard, assigns)
    else
      conn
      |> put_flash(
        :error,
        "TRACMS is available only to administrator and training management accounts."
      )
      |> redirect(to: ~p"/profile")
    end
  end

  defp common_dashboard_assigns(scope, today) do
    {role_label, context_title} = dashboard_identity(scope)

    %{
      dashboard_role_label: role_label,
      dashboard_context_title: context_title,
      dashboard_greeting: DashboardGreeting.for_utc_datetime(DateTime.utc_now()),
      greeting_name: greeting_name(scope.user),
      dashboard_date: format_dashboard_date(today),
      current_year: today.year
    }
  end

  defp manager_dashboard_assigns(
         today,
         managed_trainings,
         manageable_registrations,
         manageable_certificates
       ) do
    registration_counts_by_training = registration_counts_by_training(manageable_registrations)

    %{
      metrics: [
        metric(
          "hero-academic-cap",
          "blue",
          "Total Trainings",
          length(managed_trainings),
          "Managed training records in your current scope.",
          []
        ),
        metric(
          "hero-users",
          "green",
          "Total Registrations",
          length(manageable_registrations),
          "Participant registrations recorded in TRACMS.",
          []
        ),
        metric(
          "hero-clipboard-document-check",
          "amber",
          "Total Attendees",
          count_total_attendees(manageable_registrations),
          "Registrations with recorded attendance present, late, or excused.",
          []
        ),
        metric(
          "hero-document-check",
          "blue",
          "Certificates Generated",
          length(manageable_certificates),
          "Certificate records already issued for managed trainings.",
          []
        )
      ],
      upcoming_trainings:
        build_upcoming_training_rows(today, managed_trainings, registration_counts_by_training),
      recent_registrations: build_recent_registration_rows(manageable_registrations),
      recent_certificates: build_recent_certificate_rows(manageable_certificates),
      quick_actions: build_dashboard_quick_actions()
    }
  end

  defp metric(icon, tone, label, value, meta, details) do
    %{icon: icon, tone: tone, label: label, value: value, meta: meta, details: details}
  end

  defp build_upcoming_training_rows(today, managed_trainings, registration_counts_by_training) do
    managed_trainings
    |> Enum.filter(&future_or_today?(&1.starts_on, today))
    |> Enum.sort_by(&{&1.starts_on, &1.title})
    |> Enum.take(6)
    |> Enum.map(fn training ->
      registration_count = Map.get(registration_counts_by_training, training.id, 0)
      {status_label, status_tone} = monitoring_status(training, registration_count, today)

      %{
        title: training.title,
        schedule: format_date_range(training.starts_on, training.ends_on),
        venue: training.venue || "Venue to be announced",
        registered_count: registration_count,
        status_label: status_label,
        status_tone: status_tone,
        action_path: ~p"/registrations?training_id=#{training.id}&view=manage"
      }
    end)
  end

  defp build_recent_registration_rows(manageable_registrations) do
    manageable_registrations
    |> Enum.take(6)
    |> Enum.map(fn registration ->
      %{
        participant_name: Registrations.participant_name(registration),
        training_title: registration.training_activity.title,
        registration_date: format_timestamp(registration.inserted_at),
        action_path:
          ~p"/registrations?training_id=#{registration.training_activity.id}&view=manage"
      }
    end)
  end

  defp build_recent_certificate_rows(manageable_certificates) do
    manageable_certificates
    |> Enum.take(6)
    |> Enum.map(fn certificate ->
      %{
        participant_name: Registrations.participant_name(certificate.registration),
        training_title: certificate.registration.training_activity.title,
        certificate_number: certificate.certificate_number,
        generated_on: format_date_value(certificate.issued_on || certificate.inserted_at),
        action_path:
          ~p"/certificates?training_id=#{certificate.registration.training_activity.id}"
      }
    end)
  end

  defp build_dashboard_quick_actions do
    [
      quick_action(
        "hero-plus-circle",
        "blue",
        "Add Training",
        "Create a new training record.",
        ~p"/trainings/new"
      ),
      quick_action(
        "hero-user-group",
        "green",
        "View Registrations",
        "Open participant registration records.",
        ~p"/registrations"
      ),
      quick_action(
        "hero-clipboard-document-check",
        "amber",
        "Record Attendance",
        "Manage attendance sessions and marking.",
        ~p"/attendance"
      ),
      quick_action(
        "hero-document-check",
        "blue",
        "Generate Certificates",
        "Open the certificate workspace for issuance.",
        ~p"/certificates"
      )
    ]
  end

  defp quick_action(icon, tone, title, copy, path) do
    %{icon: icon, tone: tone, title: title, copy: copy, path: path}
  end

  defp registration_counts_by_training(registrations) do
    registrations
    |> Enum.reject(&(&1.status in [:withdrawn, :rejected]))
    |> Enum.group_by(& &1.training_activity_id)
    |> Map.new(fn {training_id, items} -> {training_id, length(items)} end)
  end

  defp monitoring_status(training, registration_count, today) do
    cond do
      training.status == :in_progress ->
        {"Ongoing", "blue"}

      training.status in [:completed, :archived] ->
        {"Completed", "slate"}

      registration_count >= training.max_capacity and
          training.status in [:published, :registration_closed] ->
        {"Full", "amber"}

      training.status == :published and future_or_today?(training.registration_deadline, today) ->
        {"Open", "green"}

      training.status == :registration_closed or past_date?(training.starts_on, today) ->
        {"Closed", "rose"}

      true ->
        {Trainings.format_status(training.status), "slate"}
    end
  end

  defp count_total_attendees(manageable_registrations) do
    registration_ids = Enum.map(manageable_registrations, & &1.id)

    if registration_ids == [] do
      0
    else
      AttendanceRecord
      |> where(
        [record],
        record.registration_id in ^registration_ids and
          record.status in ^[:present, :late, :excused]
      )
      |> select([record], count(record.registration_id, :distinct))
      |> Repo.one()
    end
  end

  defp greeting_name(user) do
    preferred_greeting_source(user)
  end

  defp dashboard_identity(scope) do
    cond do
      Scope.regional_admin?(scope) ->
        {"Regional Administrator", "Regional Training Operations Overview"}

      Scope.division_admin?(scope) ->
        {"Division Administrator", "Division Training Operations Overview"}

      Scope.coordinator?(scope) ->
        {"Training Coordinator", "Training Operations Overview"}

      true ->
        {"TRACMS Administrator", "Training Operations Overview"}
    end
  end

  defp format_dashboard_date(date) do
    "#{Calendar.strftime(date, "%B")} #{date.day}, #{date.year} | #{Calendar.strftime(date, "%A")}"
  end

  defp format_date_range(nil, nil), do: "Schedule to be announced"
  defp format_date_range(%Date{} = starts_on, nil), do: format_date_value(starts_on)
  defp format_date_range(nil, %Date{} = ends_on), do: format_date_value(ends_on)

  defp format_date_range(%Date{} = starts_on, %Date{} = ends_on) do
    if Date.compare(starts_on, ends_on) == :eq do
      format_date_value(starts_on)
    else
      "#{format_date_value(starts_on)} to #{format_date_value(ends_on)}"
    end
  end

  defp format_date_value(%Date{} = date) do
    "#{Calendar.strftime(date, "%b")} #{date.day}, #{date.year}"
  end

  defp format_date_value(%DateTime{} = datetime),
    do: format_date_value(DateTime.to_date(datetime))

  defp format_date_value(%NaiveDateTime{} = datetime),
    do: format_date_value(NaiveDateTime.to_date(datetime))

  defp format_timestamp(nil), do: "Recently updated"

  defp format_timestamp(datetime), do: format_date_value(datetime)

  defp future_or_today?(nil, _today), do: false
  defp future_or_today?(%Date{} = date, today), do: Date.compare(date, today) != :lt

  defp future_or_today?(%DateTime{} = datetime, today),
    do: future_or_today?(DateTime.to_date(datetime), today)

  defp past_date?(nil, _today), do: false
  defp past_date?(date, today), do: Date.compare(date, today) == :lt

  defp blank?(value), do: value in [nil, ""]

  defp preferred_greeting_source(%{full_name: full_name, email: email}) do
    if blank?(full_name), do: email || "User", else: full_name
  end
end
