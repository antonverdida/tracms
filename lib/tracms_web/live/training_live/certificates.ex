defmodule TracmsWeb.TrainingLive.Certificates do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Certificates.Notifier
  alias Tracms.Registrations
  alias Tracms.Trainings

  @default_filters %{"training_id" => "", "search" => ""}

  @impl true
  def mount(params, _session, socket) do
    training_id = params["training_id"] || ""

    {:ok,
     socket
     |> assign(:page_title, "Certificate Records")
     |> assign(:filters, Map.put(@default_filters, "training_id", training_id))
     |> assign(
       :manual_participant_form,
       to_form(%{"participant_names" => ""}, as: :manual_participant)
     )
     |> assign(:manual_participant_open?, false)
     |> load_page()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters =
      @default_filters
      |> Map.merge(%{
        "training_id" => params["training_id"] || "",
        "search" => params["search"] || ""
      })

    {:noreply, socket |> assign(:filters, filters) |> load_page()}
  end

  @impl true
  def handle_event("filter_certificates", %{"certificate_filters" => filters}, socket) do
    updated_filters =
      Map.merge(socket.assigns.filters, %{
        "search" => Map.get(filters, "search", "")
      })

    {:noreply,
     socket
     |> assign(:filters, updated_filters)
     |> load_page()}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{
       "training_id" => socket.assigns.filters["training_id"],
       "search" => ""
     })
     |> load_page()}
  end

  def handle_event("show_manual_participant_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:manual_participant_open?, true)
     |> assign(
       :manual_participant_form,
       to_form(%{"participant_names" => ""}, as: :manual_participant)
     )}
  end

  def handle_event("hide_manual_participant_form", _params, socket) do
    {:noreply, assign(socket, :manual_participant_open?, false)}
  end

  def handle_event("validate_manual_participants", %{"manual_participant" => params}, socket) do
    {:noreply, assign(socket, :manual_participant_form, to_form(params, as: :manual_participant))}
  end

  def handle_event("save_manual_participants", %{"manual_participant" => params}, socket) do
    case Registrations.create_manual_registrations(
           socket.assigns.current_scope,
           socket.assigns.selected_training.id,
           params["participant_names"]
         ) do
      {:ok, registrations} ->
        case issue_manual_participant_certificates(socket.assigns.current_scope, registrations) do
          {:ok, certificates} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "Added #{length(registrations)} participant#{if(length(registrations) == 1, do: "", else: "s")} and generated #{length(certificates)} certificate#{if(length(certificates) == 1, do: "", else: "s")}."
             )
             |> close_manual_participant_form()
             |> load_page()}

          {:error, :certificate_number_range_exhausted} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Participants were added, but the configured certificate number range is exhausted."
             )
             |> close_manual_participant_form()
             |> load_page()}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Participants were added, but their certificates could not be generated."
             )
             |> close_manual_participant_form()
             |> load_page()}
        end

      {:error, :no_participant_names} ->
        {:noreply, put_flash(socket, :error, "Enter at least one participant name.")}

      {:error, :capacity_reached} ->
        {:noreply,
         put_flash(socket, :error, "The selected training has reached its maximum participants.")}

      {:error, :manual_registration_not_allowed} ->
        {:noreply, put_flash(socket, :error, "Participants cannot be added to this training.")}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to add participants right now.")}
    end
  end

  def handle_event("generate_certificate", %{"registration_id" => registration_id}, socket) do
    case Certificates.issue_certificate(socket.assigns.current_scope, registration_id) do
      {:ok, _certificate} ->
        {:noreply,
         socket
         |> put_flash(:info, "Certificate generated successfully.")
         |> load_page()}

      {:error, :already_issued} ->
        {:noreply,
         put_flash(socket, :error, "A certificate already exists for this participant.")}

      {:error, :not_eligible} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Only participants marked Present in a completed training can receive certificates."
         )}

      {:error, :certificate_number_range_exhausted} ->
        {:noreply,
         put_flash(socket, :error, "The configured certificate number range is exhausted.")}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to generate the certificate right now.")}
    end
  end

  def handle_event("generate_all_certificates", _params, socket) do
    case socket.assigns.selected_training do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a completed training first.")}

      training_activity ->
        case Certificates.issue_certificates_for_training(
               socket.assigns.current_scope,
               training_activity.id
             ) do
          {:ok, certificates} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "Generated #{length(certificates)} certificate#{if(length(certificates) == 1, do: "", else: "s")}."
             )
             |> load_page()}

          {:error, :not_eligible} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Only participants marked Present in a completed training can receive certificates."
             )}

          {:error, :certificate_number_range_exhausted} ->
            {:noreply,
             put_flash(socket, :error, "The configured certificate number range is exhausted.")}

          _other ->
            {:noreply,
             put_flash(socket, :error, "Unable to generate all certificates right now.")}
        end
    end
  end

  def handle_event("email_all_certificates", _params, socket) do
    training = socket.assigns.selected_training

    results =
      socket.assigns.issued_certificates
      |> Enum.map(fn certificate ->
        case Notifier.deliver(certificate) do
          :ok ->
            _ =
              Certificates.mark_training_certificate_emailed(
                socket.assigns.current_scope,
                training.id,
                certificate.id
              )

            :sent

          {:error, :missing_email} ->
            :missing_email

          {:error, _reason} ->
            :failed
        end
      end)

    sent = Enum.count(results, &(&1 == :sent))
    missing_email = Enum.count(results, &(&1 == :missing_email))
    failed = Enum.count(results, &(&1 == :failed))

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Emailed #{sent} PDF#{if(sent == 1, do: "", else: "s")}. #{missing_email} missing email, #{failed} failed."
     )
     |> load_page()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="certificates"
    >
      <div class="portal-page-shell">
        <%= if is_nil(@selected_training) do %>
          <.portal_page_header eyebrow="Certificate Management" title="Certificate Records">
            <:actions></:actions>
          </.portal_page_header>
        <% else %>
          <.portal_page_header
            eyebrow="Certificate Management"
            title="Certificate Records"
          >
            <:actions>
              <.button
                :if={@pending_candidates != []}
                type="button"
                phx-click="generate_all_certificates"
                variant="secondary"
              >
                Generate All Certificates
              </.button>
            </:actions>
          </.portal_page_header>
        <% end %>

        <%= if is_nil(@selected_training) do %>
          <section class="panel portal-list-panel">
            <.portal_panel_header eyebrow="Training Directory" title="Choose a Training First" />

            <%= if @certificate_trainings == [] do %>
              <.portal_empty_state
                icon="hero-document-text"
                title="No Completed Trainings Available Yet"
                copy="Certificates become available after a training is completed and attendance has been finalized."
              />
            <% else %>
              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Training Title</th>
                      <th>Schedule</th>
                      <th>Venue</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={training <- @certificate_trainings}>
                      <td>
                        <div class="portal-cell-title">{training.title}</div>
                        <div class="portal-cell-meta">
                          {training.resource_speaker || "Facilitator to be assigned"}
                        </div>
                      </td>
                      <td>
                        <div class="portal-cell-title">
                          {format_date(training.starts_on)} to {format_date(training.ends_on)}
                        </div>
                        <div class="portal-cell-meta">
                          {schedule_time_label(training.start_time, training.end_time)}
                        </div>
                      </td>
                      <td>{training.venue || "Venue to be announced"}</td>
                      <td>
                        <span class={[
                          "portal-chip",
                          "portal-chip-#{training_status_tone(training.status)}"
                        ]}>
                          {Trainings.format_status(training.status)}
                        </span>
                      </td>
                      <td>
                        <.button
                          patch={training_selection_path(training.id)}
                          variant="secondary"
                        >
                          View
                        </.button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p class="mt-4 text-right text-sm text-slate-500">{@training_directory_caption}</p>
            <% end %>
          </section>
        <% else %>
          <.portal_stat_grid cards={
            certificate_summary_cards(@selected_training, @all_candidate_rows)
          } />

          <section :if={@manual_participant_open?} class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Manual Entry"
              title="Add Participants"
              meta="Enter one full name per line. Numbering is removed automatically."
            >
              <:actions>
                <.button
                  type="button"
                  phx-click="hide_manual_participant_form"
                  variant="ghost"
                >
                  Close
                </.button>
              </:actions>
            </.portal_panel_header>

            <.form
              for={@manual_participant_form}
              id="certificate-manual-participant-form"
              phx-change="validate_manual_participants"
              phx-submit="save_manual_participants"
            >
              <.input
                field={@manual_participant_form[:participant_names]}
                type="textarea"
                label="Participant Names"
                placeholder="1. Juan Cruz&#10;2. Ana Reyes&#10;3. Maria Santos"
                rows="8"
              />

              <div class="mt-6 flex flex-wrap justify-end gap-3">
                <.button
                  type="button"
                  phx-click="hide_manual_participant_form"
                  variant="ghost"
                >
                  Cancel
                </.button>
                <.button phx-disable-with="Adding Participants...">Add Participants</.button>
              </div>
            </.form>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Certificate Records"
              title="Participant Certificate Records"
            >
              <:actions>
                <.form
                  for={to_form(@filters, as: :certificate_filters)}
                  id="certificate-filter-form"
                  phx-change="filter_certificates"
                  class="certificate-records-controls flex flex-wrap items-center justify-end gap-3"
                >
                  <.input
                    field={to_form(@filters, as: :certificate_filters)[:search]}
                    type="search"
                    aria-label="Search Certificate Records"
                    placeholder="Search certificate records"
                    class="field-input w-full sm:w-96 lg:w-[28rem]"
                  />
                  <.button
                    type="button"
                    phx-click="show_manual_participant_form"
                    variant="secondary"
                  >
                    Add Participant Manually
                  </.button>
                  <.button
                    :if={@filters["search"] != ""}
                    type="button"
                    phx-click="reset_filters"
                    variant="ghost"
                  >
                    Clear
                  </.button>
                  <.button
                    :if={@issued_certificates != []}
                    href={~p"/certificates/trainings/#{@selected_training.id}/download-all"}
                    variant="secondary"
                  >
                    Download All PDFs
                  </.button>
                  <.button
                    :if={@issued_certificates != []}
                    type="button"
                    phx-click="email_all_certificates"
                    phx-disable-with="Emailing PDFs..."
                    variant="secondary"
                  >
                    Email All PDFs
                  </.button>
                  <.button patch={~p"/certificates"} variant="ghost">Back</.button>
                </.form>
              </:actions>
            </.portal_panel_header>

            <%= if @candidate_rows == [] do %>
              <.portal_empty_state
                icon="hero-document-text"
                title="No Approved Participants Yet"
                copy="Approve participant registrations to include them in certificate tracking."
              />
            <% else %>
              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>Attendance</th>
                      <th>Certificate Status</th>
                      <th>Certificate Number</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={entry <- @candidate_rows}>
                      <td>
                        <div class="portal-cell-title">{participant_name(entry.registration)}</div>
                        <div class="portal-cell-meta">
                          {Registrations.participant_email(entry.registration) || "No email provided"}
                        </div>
                      </td>
                      <td>
                        <span class={[
                          "portal-chip",
                          "portal-chip-#{attendance_status_tone(entry.attendance_record)}"
                        ]}>
                          {attendance_status_label(entry.attendance_record)}
                        </span>
                      </td>
                      <td>
                        <span class={[
                          "portal-chip",
                          "portal-chip-#{certificate_status_tone(entry.certificate)}"
                        ]}>
                          {Certificates.certificate_status_label(entry.certificate)}
                        </span>
                      </td>
                      <td>
                        {(entry.certificate && entry.certificate.certificate_number) ||
                          "Not Generated"}
                      </td>
                      <td>
                        <div :if={entry.certificate} class="flex flex-wrap gap-2">
                          <.button
                            href={
                              ~p"/certificates/trainings/#{@selected_training.id}/#{entry.certificate.id}/export"
                            }
                            variant="ghost"
                          >
                            Download PDF
                          </.button>
                          <.button
                            href={
                              ~p"/certificates/trainings/#{@selected_training.id}/#{entry.certificate.id}/print"
                            }
                            target="_blank"
                            rel="noopener"
                            variant="ghost"
                          >
                            Print
                          </.button>
                        </div>
                        <span :if={is_nil(entry.certificate)} class="portal-cell-meta">
                          {certificate_next_step(entry)}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p class="mt-4 text-right text-sm text-slate-500">
                {certificate_record_caption(@candidate_rows)}
              </p>
            <% end %>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    trainings = Certificates.list_certificate_trainings(socket.assigns.current_scope)
    requested_training_id = normalize_filter_value(socket.assigns.filters["training_id"])

    training_filter_options = [
      {"Select a completed training", ""}
      | Enum.map(trainings, &{&1.title, &1.id})
    ]

    socket =
      socket
      |> assign(:certificate_trainings, trainings)
      |> assign(:training_directory_caption, training_directory_caption(trainings))
      |> assign(:training_filter_options, training_filter_options)

    case requested_training_id do
      nil ->
        socket
        |> assign(:selected_training, nil)
        |> assign(:all_candidate_rows, [])
        |> assign(:candidate_rows, [])
        |> assign(:eligible_candidates, [])
        |> assign(:pending_candidates, [])
        |> assign(:issued_certificates, [])

      training_id ->
        case Enum.find(trainings, &(&1.id == training_id)) do
          nil ->
            socket
            |> assign(:selected_training, nil)
            |> assign(:all_candidate_rows, [])
            |> assign(:candidate_rows, [])
            |> assign(:eligible_candidates, [])
            |> assign(:pending_candidates, [])
            |> assign(:issued_certificates, [])

          training_activity ->
            _ =
              Certificates.issue_manual_certificates_for_training(
                socket.assigns.current_scope,
                training_activity.id
              )

            all_candidate_rows =
              Certificates.list_training_certificate_candidates(
                socket.assigns.current_scope,
                training_activity.id
              )

            candidate_rows =
              filter_candidates(all_candidate_rows, socket.assigns.filters["search"])

            eligible_candidates = Enum.filter(all_candidate_rows, & &1.eligible?)
            pending_candidates = Enum.filter(eligible_candidates, &is_nil(&1.certificate))
            issued_certificates = Enum.filter(all_candidate_rows, & &1.certificate)

            socket
            |> assign(:selected_training, training_activity)
            |> assign(:all_candidate_rows, all_candidate_rows)
            |> assign(:candidate_rows, candidate_rows)
            |> assign(:eligible_candidates, eligible_candidates)
            |> assign(:pending_candidates, pending_candidates)
            |> assign(:issued_certificates, issued_certificates)
        end
    end
  end

  defp filter_candidates(candidate_rows, search) do
    case normalize_filter_value(search) do
      nil ->
        candidate_rows

      search_term ->
        normalized_search = String.downcase(search_term)

        Enum.filter(candidate_rows, fn entry ->
          [
            participant_name(entry.registration),
            Registrations.participant_email(entry.registration),
            organization_name(entry.registration)
          ]
          |> Enum.join(" ")
          |> String.downcase()
          |> String.contains?(normalized_search)
        end)
    end
  end

  defp close_manual_participant_form(socket) do
    socket
    |> assign(:manual_participant_open?, false)
    |> assign(
      :manual_participant_form,
      to_form(%{"participant_names" => ""}, as: :manual_participant)
    )
  end

  defp issue_manual_participant_certificates(scope, registrations) do
    Enum.reduce_while(registrations, {:ok, []}, fn registration, {:ok, certificates} ->
      case Certificates.issue_certificate(scope, registration.id) do
        {:ok, certificate} ->
          {:cont, {:ok, [certificate | certificates]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp certificate_summary_cards(training_activity, candidate_rows) do
    eligible_count = Enum.count(candidate_rows, & &1.eligible?)

    generated_count =
      Enum.count(candidate_rows, &match?(%{certificate: %{delivery_status: :available}}, &1))

    released_count = Enum.count(candidate_rows, &released_certificate?(&1.certificate))

    [
      summary_card(
        "Eligible Participants",
        eligible_count,
        "Present participants from #{training_activity.title}"
      ),
      summary_card(
        "Generated",
        generated_count,
        "Certificate records ready for preview or release"
      ),
      summary_card("Released", released_count, "Certificates already downloaded or printed")
    ]
  end

  defp certificate_record_caption(candidate_rows) do
    "Showing #{length(candidate_rows)} participant certificate record#{if(length(candidate_rows) == 1, do: "", else: "s")} ."
  end

  defp attendance_status_label(%{status: :present}), do: "Present"
  defp attendance_status_label(%{status: :late}), do: "Late"
  defp attendance_status_label(%{status: :excused}), do: "Excused"
  defp attendance_status_label(%{status: :absent}), do: "Absent"
  defp attendance_status_label(_record), do: "Not Recorded"

  defp attendance_status_tone(%{status: status}) when status in [:present, :late, :excused],
    do: "green"

  defp attendance_status_tone(%{status: :absent}), do: "rose"
  defp attendance_status_tone(_record), do: "amber"

  defp certificate_next_step(%{eligible?: true}), do: "Ready to generate"
  defp certificate_next_step(%{attendance_record: nil}), do: "Mark attendance first"
  defp certificate_next_step(_entry), do: "Present attendance is required"

  defp training_directory_caption(trainings) do
    count = length(trainings)

    "#{count} completed #{if(count == 1, do: "training", else: "trainings")} ready for certificate management."
  end

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> "green"
      status in [:draft, :pending_division_approval, :pending_region_approval] -> "amber"
      status in [:completed, :archived] -> "blue"
      status == :cancelled -> "rose"
      true -> "slate"
    end
  end

  defp schedule_time_label(nil, nil), do: "Time to be announced"
  defp schedule_time_label(start_time, nil), do: "#{format_time(start_time)} start"
  defp schedule_time_label(nil, end_time), do: "Until #{format_time(end_time)}"

  defp schedule_time_label(start_time, end_time) do
    "#{format_time(start_time)} to #{format_time(end_time)}"
  end

  defp training_selection_path(training_id) do
    "/certificates?" <> URI.encode_query(%{"training_id" => training_id})
  end

  defp participant_name(registration) do
    Registrations.participant_name(registration)
  end

  defp organization_name(registration) do
    Registrations.participant_organization(registration)
  end

  defp certificate_status_tone(nil), do: "slate"
  defp certificate_status_tone(%{delivery_status: :available}), do: "blue"
  defp certificate_status_tone(%{delivery_status: _status}), do: "green"

  defp released_certificate?(%{delivery_status: :available}), do: false
  defp released_certificate?(%{}), do: true
  defp released_certificate?(nil), do: false

  defp normalize_filter_value(value) when value in [nil, ""], do: nil

  defp normalize_filter_value(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end
end
