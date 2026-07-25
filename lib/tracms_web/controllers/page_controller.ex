defmodule TracmsWeb.PageController do
  use TracmsWeb, :controller

  alias Tracms.Accounts.Scope
  alias Tracms.Certificates
  alias Tracms.Evaluations
  alias Tracms.Registrations
  alias Tracms.Trainings

  def home(conn, _params) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      redirect(conn, to: ~p"/dashboard")
    else
      render(conn, :home)
    end
  end

  def dashboard(conn, _params) do
    scope = conn.assigns.current_scope
    today = Date.utc_today()
    open_trainings = Registrations.list_open_training_activities(scope)
    my_registrations = Registrations.list_user_registrations(scope)
    my_certificates = Certificates.list_user_certificates(scope)
    managed_trainings = Trainings.list_training_activities(scope)
    manageable_registrations = Registrations.list_manageable_registrations(scope)
    manageable_certificates = Certificates.list_manageable_certificates(scope)
    evaluation_submissions = load_evaluation_submissions(my_registrations)

    assigns =
      common_dashboard_assigns(scope, today)
      |> Map.merge(
        if Scope.training_manager?(scope) do
          manager_dashboard_assigns(
            scope,
            today,
            managed_trainings,
            manageable_registrations,
            manageable_certificates
          )
        else
          participant_dashboard_assigns(
            today,
            open_trainings,
            my_registrations,
            evaluation_submissions,
            my_certificates
          )
        end
      )

    render(conn, :dashboard, assigns)
  end

  defp common_dashboard_assigns(scope, today) do
    {role_label, context_title} = dashboard_identity(scope)

    %{
      dashboard_role_label: role_label,
      dashboard_context_title: context_title,
      greeting_name: greeting_name(scope.user),
      dashboard_date: format_dashboard_date(today),
      current_year: today.year
    }
  end

  defp manager_dashboard_assigns(
         scope,
         today,
         managed_trainings,
         manageable_registrations,
         manageable_certificates
       ) do
    active_registration_count = count_active_registrations(manageable_registrations)
    unique_participant_count = count_unique_participants(manageable_registrations)

    submitted_registration_count =
      Enum.count(manageable_registrations, &(&1.status == :submitted))

    waitlisted_registration_count =
      Enum.count(manageable_registrations, &(&1.status == :waitlisted))

    completed_training_count = count_trainings(managed_trainings, [:completed, :archived])

    active_training_count =
      count_trainings(managed_trainings, [:published, :registration_closed, :in_progress])

    approval_training_count =
      count_trainings(managed_trainings, [
        :draft,
        :pending_division_approval,
        :pending_region_approval
      ])

    current_month_registration_count = count_created_in_month(manageable_registrations, today)
    pending_action_count = approval_training_count + submitted_registration_count
    registration_counts_by_training = registration_counts_by_training(manageable_registrations)
    issued_certificate_count = length(manageable_certificates)
    downloaded_certificate_count = count_delivery_status(manageable_certificates, :downloaded)
    available_certificate_count = count_delivery_status(manageable_certificates, :available)
    issued_this_month_count = count_created_in_month(manageable_certificates, today)
    first_training = List.first(managed_trainings)

    %{
      dashboard_mode: :manager,
      dashboard_intro: "#{management_scope_label(scope)} dashboard",
      metrics: [
        metric(
          "hero-academic-cap",
          "blue",
          "Total Trainings",
          length(managed_trainings),
          nil,
          [
            metric_detail("Active", active_training_count, "green"),
            metric_detail("Completed", completed_training_count, "blue"),
            metric_detail("Draft / Approval", approval_training_count, "amber")
          ]
        ),
        metric(
          "hero-users",
          "green",
          "Participants",
          unique_participant_count,
          nil,
          [
            metric_detail("Active Registrations", active_registration_count, "green"),
            metric_detail("Awaiting Review", submitted_registration_count, "amber"),
            metric_detail("This Month", current_month_registration_count, "blue")
          ]
        ),
        metric(
          "hero-document-check",
          "amber",
          "Certificates Issued",
          issued_certificate_count,
          nil,
          [
            metric_detail("Available", available_certificate_count, "blue"),
            metric_detail("Acknowledged", downloaded_certificate_count, "green"),
            metric_detail("This Month", issued_this_month_count, "amber")
          ]
        ),
        metric(
          "hero-exclamation-triangle",
          "rose",
          "Pending Actions",
          pending_action_count,
          nil,
          [
            metric_detail("Approval Requests", approval_training_count, "amber"),
            metric_detail("Registration Review", submitted_registration_count, "blue"),
            metric_detail("Waitlisted", waitlisted_registration_count, "rose")
          ]
        )
      ],
      upcoming_items:
        build_manager_upcoming_items(today, managed_trainings, registration_counts_by_training),
      status_items: build_manager_status_items(managed_trainings),
      status_note: build_manager_status_note(managed_trainings),
      workflow_items: build_manager_workflow_items(manageable_registrations),
      monitoring_rows:
        build_manager_monitoring_rows(today, managed_trainings, registration_counts_by_training),
      quick_actions: build_manager_quick_actions(first_training),
      recent_activities:
        build_manager_recent_activities(
          managed_trainings,
          manageable_registrations,
          manageable_certificates
        ),
      workflow_link: manager_training_link(first_training, :registrations)
    }
  end

  defp participant_dashboard_assigns(
         today,
         open_trainings,
         my_registrations,
         evaluation_submissions,
         my_certificates
       ) do
    approved_registration_count = Enum.count(my_registrations, &(&1.status == :approved))

    follow_up_registration_count =
      Enum.count(my_registrations, &(&1.status in [:submitted, :waitlisted]))

    pending_evaluations =
      pending_evaluation_registrations(my_registrations, evaluation_submissions)

    pending_action_count = follow_up_registration_count + length(pending_evaluations)
    upcoming_registration_count = count_upcoming_registrations(my_registrations, today)
    certificates_by_registration_id = certificate_map_by_registration(my_certificates)
    issued_certificate_count = length(my_certificates)
    downloaded_certificate_count = count_delivery_status(my_certificates, :downloaded)
    available_certificate_count = count_delivery_status(my_certificates, :available)

    awaiting_certificate_count =
      Enum.count(my_registrations, fn registration ->
        registration.status == :approved and
          not Map.has_key?(certificates_by_registration_id, registration.id)
      end)

    %{
      dashboard_mode: :participant,
      dashboard_intro: "Personal training and evaluation overview",
      metrics: [
        metric(
          "hero-academic-cap",
          "blue",
          "Upcoming Trainings",
          upcoming_registration_count,
          "Submitted or approved activities on your schedule",
          [
            metric_detail("Open Catalog", length(open_trainings), "blue"),
            metric_detail("Approved", approved_registration_count, "green"),
            metric_detail("Awaiting Update", follow_up_registration_count, "amber")
          ]
        ),
        metric(
          "hero-clipboard-document-list",
          "green",
          "My Registrations",
          length(my_registrations),
          "Records currently saved in TRACMS",
          [
            metric_detail("Approved", approved_registration_count, "green"),
            metric_detail("Follow-Up Required", follow_up_registration_count, "amber"),
            metric_detail(
              "Rejected / Withdrawn",
              count_closed_registrations(my_registrations),
              "rose"
            )
          ]
        ),
        metric(
          "hero-document-check",
          "amber",
          "Certificates",
          issued_certificate_count,
          "Issued certificate records connected to your trainings",
          [
            metric_detail("Available", available_certificate_count, "blue"),
            metric_detail("Acknowledged", downloaded_certificate_count, "green"),
            metric_detail("Awaiting Release", awaiting_certificate_count, "amber")
          ]
        ),
        metric(
          "hero-exclamation-triangle",
          "rose",
          "Pending Actions",
          pending_action_count,
          "Registrations or evaluations that still need your attention",
          [
            metric_detail("Registration Follow-Up", follow_up_registration_count, "blue"),
            metric_detail("Pending Evaluations", length(pending_evaluations), "rose"),
            metric_detail("Open Trainings", length(open_trainings), "green")
          ]
        )
      ],
      upcoming_items:
        build_participant_upcoming_items(
          today,
          open_trainings,
          my_registrations,
          evaluation_submissions
        ),
      status_items: build_participant_status_items(my_registrations),
      status_note: build_participant_status_note(open_trainings, pending_evaluations),
      workflow_items:
        build_participant_workflow_items(
          my_registrations,
          pending_evaluations,
          evaluation_submissions
        ),
      monitoring_rows:
        build_participant_monitoring_rows(
          my_registrations,
          evaluation_submissions,
          certificates_by_registration_id
        ),
      quick_actions: build_participant_quick_actions(pending_evaluations),
      recent_activities: build_participant_recent_activities(my_registrations, my_certificates),
      workflow_link: ~p"/my/registrations"
    }
  end

  defp metric(icon, tone, label, value, meta, details) do
    %{icon: icon, tone: tone, label: label, value: value, meta: meta, details: details}
  end

  defp metric_detail(label, value, tone) do
    %{label: label, value: value, tone: tone}
  end

  defp build_manager_upcoming_items(today, managed_trainings, registration_counts_by_training) do
    managed_trainings
    |> Enum.filter(&future_or_today?(&1.starts_on, today))
    |> Enum.sort_by(&{&1.starts_on, &1.title})
    |> Enum.take(3)
    |> Enum.map(fn training ->
      %{
        month: format_short_month(training.starts_on),
        day: format_day_number(training.starts_on),
        title: training.title,
        badges: [modality_label(training.modality), Trainings.format_status(training.status)],
        meta_primary:
          [training.category, training.venue] |> Enum.reject(&blank?/1) |> Enum.join(" • "),
        meta_secondary:
          "#{Map.get(registration_counts_by_training, training.id, 0)} / #{training.max_capacity} active registrations",
        action_label: "Open record",
        action_path: ~p"/trainings/#{training.id}"
      }
    end)
  end

  defp build_participant_upcoming_items(
         today,
         open_trainings,
         my_registrations,
         evaluation_submissions
       ) do
    my_upcoming =
      my_registrations
      |> Enum.filter(fn registration ->
        registration.status in [:submitted, :approved, :waitlisted] and
          future_or_today?(registration.training_activity.starts_on, today)
      end)
      |> Enum.sort_by(fn registration ->
        {registration.training_activity.starts_on, registration.training_activity.title}
      end)
      |> Enum.take(3)
      |> Enum.map(fn registration ->
        training = registration.training_activity

        %{
          month: format_short_month(training.starts_on),
          day: format_day_number(training.starts_on),
          title: training.title,
          badges: [
            Registrations.format_status(registration.status),
            modality_label(training.modality)
          ],
          meta_primary:
            [format_long_date(training.starts_on), training.venue]
            |> Enum.reject(&blank?/1)
            |> Enum.join(" • "),
          meta_secondary: participant_next_step(registration, evaluation_submissions),
          action_label: "Open records",
          action_path: ~p"/my/registrations"
        }
      end)

    if my_upcoming == [] do
      open_trainings
      |> Enum.take(3)
      |> Enum.map(fn training ->
        %{
          month: format_short_month(training.starts_on),
          day: format_day_number(training.starts_on),
          title: training.title,
          badges: [modality_label(training.modality), Trainings.format_status(training.status)],
          meta_primary:
            [training.category, training.venue] |> Enum.reject(&blank?/1) |> Enum.join(" • "),
          meta_secondary:
            "Registration closes #{format_datetime(training.registration_deadline)}",
          action_label: "Browse catalog",
          action_path: ~p"/catalog/trainings"
        }
      end)
    else
      my_upcoming
    end
  end

  defp build_manager_status_items(managed_trainings) do
    counts = Enum.frequencies_by(managed_trainings, & &1.status)
    total = max(length(managed_trainings), 1)

    [
      status_item(
        "Draft",
        counts[:draft] || 0,
        total,
        "New activities not yet submitted",
        "amber"
      ),
      status_item(
        "For Approval",
        (counts[:pending_division_approval] || 0) + (counts[:pending_region_approval] || 0),
        total,
        "Awaiting division or region action",
        "blue"
      ),
      status_item(
        "Published",
        (counts[:published] || 0) + (counts[:registration_closed] || 0),
        total,
        "Visible in the catalog or in registration delivery",
        "indigo"
      ),
      status_item(
        "Ongoing",
        counts[:in_progress] || 0,
        total,
        "Currently in delivery and attendance tracking",
        "green"
      ),
      status_item(
        "Completed",
        counts[:completed] || 0,
        total,
        "Ready for completion review and records",
        "slate"
      )
    ]
  end

  defp build_participant_status_items(my_registrations) do
    counts = Enum.frequencies_by(my_registrations, & &1.status)
    total = max(length(my_registrations), 1)

    [
      status_item(
        "Submitted",
        counts[:submitted] || 0,
        total,
        "Awaiting final review or confirmation",
        "blue"
      ),
      status_item(
        "Approved",
        counts[:approved] || 0,
        total,
        "Ready for attendance and completion steps",
        "green"
      ),
      status_item(
        "Waitlisted",
        counts[:waitlisted] || 0,
        total,
        "Queued until capacity becomes available",
        "amber"
      ),
      status_item(
        "Rejected",
        counts[:rejected] || 0,
        total,
        "Not approved for the selected activity",
        "rose"
      ),
      status_item(
        "Withdrawn",
        counts[:withdrawn] || 0,
        total,
        "Removed from your active records",
        "slate"
      )
    ]
  end

  defp build_manager_status_note(managed_trainings) do
    archived_count = count_trainings(managed_trainings, [:archived])

    if archived_count > 0 do
      "#{archived_count} archived record(s) remain available in management history."
    else
      "Use training management to advance draft, approval, and delivery records in one place."
    end
  end

  defp build_participant_status_note(open_trainings, pending_evaluations) do
    cond do
      length(pending_evaluations) > 0 ->
        "#{length(pending_evaluations)} approved registration(s) still need evaluation or follow-up."

      open_trainings != [] ->
        "#{length(open_trainings)} published training(s) are currently open for registration."

      true ->
        "Browse the training catalog when new activities are published for your account."
    end
  end

  defp build_manager_workflow_items(manageable_registrations) do
    counts = Enum.frequencies_by(manageable_registrations, & &1.status)

    [
      workflow_item(
        "Submitted",
        counts[:submitted] || 0,
        "Needs coordinator, division, or region review",
        "blue"
      ),
      workflow_item("Approved", counts[:approved] || 0, "Confirmed participant records", "green"),
      workflow_item(
        "Waitlisted",
        counts[:waitlisted] || 0,
        "Held while capacity is limited",
        "amber"
      ),
      workflow_item("Rejected", counts[:rejected] || 0, "Not accepted into the activity", "rose"),
      workflow_item(
        "Withdrawn",
        counts[:withdrawn] || 0,
        "Removed from the active roster",
        "slate"
      )
    ]
  end

  defp build_participant_workflow_items(
         my_registrations,
         pending_evaluations,
         evaluation_submissions
       ) do
    approved_registrations = Enum.count(my_registrations, &(&1.status == :approved))

    not_required_count =
      Enum.count(my_registrations, fn registration ->
        registration.status == :approved and
          not registration.training_activity.evaluation_required
      end)

    [
      workflow_item(
        "Approved",
        approved_registrations,
        "Eligible for attendance and completion tracking",
        "green"
      ),
      workflow_item(
        "Pending Evaluation",
        length(pending_evaluations),
        "Approved trainings still waiting for your evaluation",
        "amber"
      ),
      workflow_item(
        "Submitted Evaluation",
        map_size(evaluation_submissions),
        "Evaluation forms already recorded in TRACMS",
        "blue"
      ),
      workflow_item(
        "No Evaluation Required",
        not_required_count,
        "Approved trainings without an evaluation step",
        "slate"
      )
    ]
  end

  defp build_manager_monitoring_rows(today, managed_trainings, registration_counts_by_training) do
    managed_trainings
    |> Enum.sort_by(
      &{future_weight(&1.starts_on, today), &1.starts_on || ~D[2099-12-31], &1.title}
    )
    |> Enum.take(5)
    |> Enum.map(fn training ->
      registration_count = Map.get(registration_counts_by_training, training.id, 0)
      {status_label, status_tone} = monitoring_status(training, registration_count, today)

      %{
        title: training.title,
        metric: registration_count,
        capacity: training.max_capacity,
        status_label: status_label,
        status_tone: status_tone,
        action_path: ~p"/trainings/#{training.id}/registrations"
      }
    end)
  end

  defp build_participant_monitoring_rows(
         my_registrations,
         evaluation_submissions,
         certificates_by_registration_id
       ) do
    my_registrations
    |> Enum.take(5)
    |> Enum.map(fn registration ->
      training = registration.training_activity
      certificate = Map.get(certificates_by_registration_id, registration.id)

      %{
        title: training.title,
        schedule: format_long_date(training.starts_on),
        status_label: Registrations.format_status(registration.status),
        status_tone: registration_tone(registration.status),
        evaluation_label: participant_evaluation_label(registration, evaluation_submissions),
        certificate_label: participant_certificate_label(certificate),
        action_path: participant_action_path(registration, evaluation_submissions, certificate)
      }
    end)
  end

  defp build_manager_quick_actions(first_training) do
    [
      quick_action(
        "hero-plus-circle",
        "blue",
        "Create Training",
        "Add a new training record.",
        ~p"/trainings/new"
      ),
      quick_action(
        "hero-rectangle-stack",
        "green",
        "Manage Trainings",
        "Review schedules and status.",
        ~p"/trainings"
      ),
      quick_action(
        "hero-user-group",
        "amber",
        "Review Registrations",
        "Process participant requests.",
        manager_training_link(first_training, :registrations)
      ),
      quick_action(
        "hero-qr-code",
        "rose",
        "Attendance Tracking",
        "Open attendance sessions.",
        manager_training_link(first_training, :attendance)
      ),
      quick_action(
        "hero-clipboard-document-check",
        "slate",
        "Completion Review",
        "Review completion results.",
        manager_training_link(first_training, :completion)
      ),
      quick_action(
        "hero-document-check",
        "green",
        "Certificates",
        "Issue and review certificate records.",
        manager_training_link(first_training, :certificates)
      ),
      quick_action(
        "hero-chart-bar-square",
        "blue",
        "Reports",
        "Open training operations summaries.",
        ~p"/reports"
      )
    ]
  end

  defp build_participant_quick_actions(pending_evaluations) do
    [
      quick_action(
        "hero-book-open",
        "blue",
        "Browse Trainings",
        "View available activities.",
        ~p"/catalog/trainings"
      ),
      quick_action(
        "hero-identification",
        "green",
        "My Registrations",
        "Track submitted records.",
        ~p"/my/registrations"
      ),
      quick_action(
        "hero-clipboard-document-check",
        "amber",
        "Submit Evaluation",
        "Complete required feedback.",
        participant_evaluation_path(pending_evaluations)
      ),
      quick_action(
        "hero-document-check",
        "green",
        "My Certificates",
        "Open issued training credentials.",
        ~p"/my/certificates"
      ),
      quick_action(
        "hero-cog-6-tooth",
        "slate",
        "Account Settings",
        "Update your sign-in details.",
        ~p"/users/settings"
      )
    ]
  end

  defp build_manager_recent_activities(
         managed_trainings,
         manageable_registrations,
         manageable_certificates
       ) do
    training_activities =
      Enum.map(managed_trainings, fn training ->
        %{
          sort_at: training.inserted_at,
          icon: "hero-academic-cap",
          tone: "blue",
          title: training.title,
          detail: "Training status: #{Trainings.format_status(training.status)}",
          timestamp: format_timestamp(training.inserted_at)
        }
      end)

    registration_activities =
      Enum.map(manageable_registrations, fn registration ->
        registrant = registration.registrant_user.full_name || registration.registrant_user.email

        %{
          sort_at: registration.inserted_at,
          icon: "hero-user-plus",
          tone: registration_tone(registration.status),
          title: "#{registrant} registration update",
          detail:
            "#{registration.training_activity.title} • #{Registrations.format_status(registration.status)}",
          timestamp: format_timestamp(registration.inserted_at)
        }
      end)

    certificate_activities =
      Enum.map(manageable_certificates, fn certificate ->
        participant = certificate.registration.registrant_user
        participant_name = participant.full_name || participant.email

        %{
          sort_at: certificate.inserted_at,
          icon: "hero-document-check",
          tone: delivery_status_tone(certificate.delivery_status),
          title: "#{participant_name} certificate issued",
          detail:
            "#{certificate.registration.training_activity.title} • #{Certificates.format_delivery_status(certificate.delivery_status)}",
          timestamp: format_timestamp(certificate.inserted_at)
        }
      end)

    recent_activities(training_activities ++ registration_activities ++ certificate_activities)
  end

  defp build_participant_recent_activities(my_registrations, my_certificates) do
    registration_activities =
      Enum.map(my_registrations, fn registration ->
        %{
          sort_at: registration.inserted_at,
          icon: "hero-clipboard-document-list",
          tone: registration_tone(registration.status),
          title: registration.training_activity.title,
          detail: "Registration status: #{Registrations.format_status(registration.status)}",
          timestamp: format_timestamp(registration.inserted_at)
        }
      end)

    certificate_activities =
      Enum.map(my_certificates, fn certificate ->
        %{
          sort_at: certificate.inserted_at,
          icon: "hero-document-check",
          tone: delivery_status_tone(certificate.delivery_status),
          title: certificate.registration.training_activity.title,
          detail:
            "Certificate record: #{Certificates.format_delivery_status(certificate.delivery_status)}",
          timestamp: format_timestamp(certificate.inserted_at)
        }
      end)

    recent_activities(registration_activities ++ certificate_activities)
  end

  defp recent_activities(activities) do
    activities
    |> Enum.sort_by(&DateTime.to_unix(&1.sort_at, :second), :desc)
    |> Enum.take(4)
  end

  defp status_item(label, value, total, description, tone) do
    percent =
      if total == 0 do
        0
      else
        round(value * 100 / total)
      end

    %{label: label, value: value, percent: percent, description: description, tone: tone}
  end

  defp workflow_item(label, value, description, tone) do
    %{label: label, value: value, description: description, tone: tone}
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

  defp pending_evaluation_registrations(my_registrations, evaluation_submissions) do
    Enum.filter(my_registrations, fn registration ->
      registration.status == :approved and
        registration.training_activity.evaluation_required and
        not Map.has_key?(evaluation_submissions, registration.id)
    end)
  end

  defp participant_next_step(registration, evaluation_submissions) do
    cond do
      registration.status != :approved ->
        "Status: #{Registrations.format_status(registration.status)}"

      registration.training_activity.evaluation_required and
          not Map.has_key?(evaluation_submissions, registration.id) ->
        "Evaluation still required before completion review"

      registration.training_activity.evaluation_required ->
        "Evaluation already submitted"

      true ->
        "No additional evaluation requirement"
    end
  end

  defp participant_evaluation_label(registration, evaluation_submissions) do
    cond do
      registration.status != :approved ->
        "Awaiting approval"

      not registration.training_activity.evaluation_required ->
        "Not required"

      Map.has_key?(evaluation_submissions, registration.id) ->
        "Submitted"

      true ->
        "Pending"
    end
  end

  defp participant_action_path(registration, evaluation_submissions, certificate) do
    cond do
      certificate ->
        ~p"/my/certificates/#{certificate.id}"

      registration.status == :approved and
        registration.training_activity.evaluation_required and
          not Map.has_key?(evaluation_submissions, registration.id) ->
        ~p"/my/registrations/#{registration.id}/evaluation"

      true ->
        ~p"/my/registrations"
    end
  end

  defp participant_evaluation_path([registration | _pending]) do
    ~p"/my/registrations/#{registration.id}/evaluation"
  end

  defp participant_evaluation_path([]), do: ~p"/my/registrations"

  defp manager_training_link(nil, _target), do: ~p"/trainings"

  defp manager_training_link(training, :registrations),
    do: ~p"/trainings/#{training.id}/registrations"

  defp manager_training_link(training, :attendance), do: ~p"/trainings/#{training.id}/attendance"
  defp manager_training_link(training, :completion), do: ~p"/trainings/#{training.id}/completion"

  defp manager_training_link(training, :certificates),
    do: ~p"/trainings/#{training.id}/certificates"

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

  defp count_active_registrations(registrations) do
    Enum.count(registrations, &(&1.status in [:submitted, :approved, :waitlisted]))
  end

  defp count_unique_participants(registrations) do
    registrations
    |> Enum.map(& &1.registrant_user_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp count_created_in_month(items, today) do
    Enum.count(items, &same_month?(&1.inserted_at, today))
  end

  defp count_trainings(trainings, statuses) do
    Enum.count(trainings, &(&1.status in statuses))
  end

  defp count_upcoming_registrations(registrations, today) do
    Enum.count(registrations, fn registration ->
      registration.status in [:submitted, :approved, :waitlisted] and
        future_or_today?(registration.training_activity.starts_on, today)
    end)
  end

  defp count_closed_registrations(registrations) do
    Enum.count(registrations, &(&1.status in [:rejected, :withdrawn]))
  end

  defp count_delivery_status(certificates, status) do
    Enum.count(certificates, &(&1.delivery_status == status))
  end

  defp certificate_map_by_registration(certificates) do
    Map.new(certificates, &{&1.registration_id, &1})
  end

  defp load_evaluation_submissions(registrations) do
    registrations
    |> Enum.filter(fn registration ->
      registration.status == :approved and registration.training_activity.evaluation_required
    end)
    |> Enum.map(& &1.id)
    |> Evaluations.list_submission_map()
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
        {"Participant", "My Learning Record Overview"}
    end
  end

  defp management_scope_label(scope) do
    cond do
      Scope.regional_admin?(scope) -> "Regional operations"
      Scope.division_admin?(scope) -> "Division operations"
      Scope.coordinator?(scope) -> "Coordinator operations"
      true -> "Training operations"
    end
  end

  defp format_dashboard_date(date) do
    "#{Calendar.strftime(date, "%B")} #{date.day}, #{date.year} | #{Calendar.strftime(date, "%A")}"
  end

  defp format_long_date(nil), do: "Schedule to be announced"

  defp format_long_date(date) do
    "#{Calendar.strftime(date, "%B")} #{date.day}, #{date.year}"
  end

  defp format_short_month(nil), do: "--"
  defp format_short_month(date), do: Calendar.strftime(date, "%b")

  defp format_day_number(nil), do: "--"
  defp format_day_number(date), do: String.pad_leading(Integer.to_string(date.day), 2, "0")

  defp format_datetime(nil), do: "schedule to be announced"

  defp format_datetime(datetime) do
    date = DateTime.to_date(datetime)
    "#{Calendar.strftime(date, "%b")} #{date.day}, #{date.year}"
  end

  defp format_timestamp(nil), do: "Recently updated"

  defp format_timestamp(datetime) do
    date = DateTime.to_date(datetime)
    "#{Calendar.strftime(date, "%b")} #{date.day}, #{date.year}"
  end

  defp modality_label(:face_to_face), do: "Face-to-Face"
  defp modality_label(:online), do: "Online"
  defp modality_label(:hybrid), do: "Hybrid"
  defp modality_label(_modality), do: "Scheduled"

  defp registration_tone(:approved), do: "green"
  defp registration_tone(:submitted), do: "blue"
  defp registration_tone(:waitlisted), do: "amber"
  defp registration_tone(:rejected), do: "rose"
  defp registration_tone(:withdrawn), do: "slate"
  defp registration_tone(_status), do: "slate"

  defp delivery_status_tone(:downloaded), do: "green"
  defp delivery_status_tone(:emailed), do: "blue"
  defp delivery_status_tone(:available), do: "amber"
  defp delivery_status_tone(_status), do: "slate"

  defp participant_certificate_label(nil), do: "Awaiting issuance"

  defp participant_certificate_label(certificate) do
    "#{Certificates.format_delivery_status(certificate.delivery_status)} • #{certificate.certificate_number}"
  end

  defp future_or_today?(nil, _today), do: false
  defp future_or_today?(%Date{} = date, today), do: Date.compare(date, today) != :lt

  defp future_or_today?(%DateTime{} = datetime, today),
    do: future_or_today?(DateTime.to_date(datetime), today)

  defp same_month?(nil, _today), do: false

  defp same_month?(%DateTime{} = datetime, today) do
    same_month?(DateTime.to_date(datetime), today)
  end

  defp same_month?(%NaiveDateTime{} = datetime, today) do
    same_month?(NaiveDateTime.to_date(datetime), today)
  end

  defp same_month?(%Date{} = date, today) do
    date.year == today.year and date.month == today.month
  end

  defp past_date?(nil, _today), do: false
  defp past_date?(date, today), do: Date.compare(date, today) == :lt

  defp future_weight(nil, _today), do: 2

  defp future_weight(date, today) do
    if future_or_today?(date, today), do: 0, else: 1
  end

  defp blank?(value), do: value in [nil, ""]

  defp preferred_greeting_source(%{full_name: full_name, email: email}) do
    if blank?(full_name), do: email || "User", else: full_name
  end
end
