defmodule TracmsWeb.TrainingLive.RegistrationManagement do
  use TracmsWeb, :live_view

  alias Tracms.Registrations
  alias Tracms.Trainings

  @default_filters %{"search" => "", "training_id" => ""}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "List of Registrations")
     |> assign(:filters, @default_filters)
     |> assign(:view_mode, :directory)
     |> assign(:selected_registration, nil)
     |> assign(:editing_registration, nil)
     |> assign(:manual_registration_open?, false)
     |> assign_manual_form(default_manual_registration_params())
     |> assign(:edit_registration_form, nil)
     |> load_registration_list()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters =
      @default_filters
      |> Map.merge(%{
        "training_id" => params["training_id"] || "",
        "search" => params["search"] || ""
      })

    view_mode = registration_view_mode(filters["training_id"], params["view"])

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:view_mode, view_mode)
     |> load_registration_list()
     |> apply_manual_entry_mode(params["manual"])}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    updated_filters =
      Map.merge(socket.assigns.filters, %{
        "search" => Map.get(filters, "search", "")
      })

    {:noreply,
     socket
     |> assign(:filters, updated_filters)
     |> load_registration_list()}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{
       "training_id" => socket.assigns.filters["training_id"],
       "search" => ""
     })
     |> load_registration_list()}
  end

  def handle_event("show_registration", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:manual_registration_open?, false)
     |> assign(:editing_registration, nil)
     |> assign(:edit_registration_form, nil)
     |> assign(:selected_registration, find_registration(socket, id))}
  end

  def handle_event("hide_registration", _params, socket) do
    {:noreply, assign(socket, :selected_registration, nil)}
  end

  def handle_event("show_manual_registration", _params, socket) do
    {:noreply, open_manual_registration(socket)}
  end

  def handle_event("cancel_manual_registration", _params, socket) do
    {:noreply,
     socket
     |> assign(:manual_registration_open?, false)
     |> assign_manual_form(default_manual_registration_params())}
  end

  def handle_event("validate_manual_registration", %{"manual_registration" => params}, socket) do
    {:noreply, assign_manual_form(socket, params)}
  end

  def handle_event("save_manual_registration", %{"manual_registration" => params}, socket) do
    case Registrations.create_manual_registrations(
           socket.assigns.current_scope,
           socket.assigns.selected_training.id,
           params["participant_names"]
         ) do
      {:ok, registrations} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Added #{length(registrations)} participant#{if(length(registrations) == 1, do: "", else: "s")} successfully."
         )
         |> assign(:manual_registration_open?, false)
         |> assign_manual_form(default_manual_registration_params())
         |> load_registration_list()}

      {:error, :no_participant_names} ->
        {:noreply, put_flash(socket, :error, "Enter at least one participant name.")}

      {:error, :capacity_reached} ->
        {:noreply,
         put_flash(socket, :error, "The selected training has reached its maximum participants.")}

      {:error, :manual_registration_not_allowed} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Participants cannot be added to a cancelled or archived training."
         )}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to add participants right now.")}
    end
  end

  def handle_event("edit_registration", %{"id" => id}, socket) do
    registration = find_registration(socket, id)

    {:noreply,
     socket
     |> assign(:manual_registration_open?, false)
     |> assign(:selected_registration, registration)
     |> assign(:editing_registration, registration)
     |> assign_edit_form(registration)}
  end

  def handle_event("cancel_edit_registration", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_registration, nil)
     |> assign(:edit_registration_form, nil)}
  end

  def handle_event("validate_edit_registration", %{"edit_registration" => params}, socket) do
    changeset =
      socket.assigns.editing_registration
      |> Registrations.change_manager_registration(normalize_edit_params(params))
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket, :edit_registration_form, to_form(changeset, as: :edit_registration))}
  end

  def handle_event("save_edit_registration", %{"edit_registration" => params}, socket) do
    case Registrations.update_registration(
           socket.assigns.current_scope,
           socket.assigns.editing_registration,
           normalize_edit_params(params)
         ) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration updated successfully.")
         |> assign(:editing_registration, nil)
         |> assign(:edit_registration_form, nil)
         |> load_registration_list()}

      {:error, :training_not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The selected training could not be found in your current scope."
         )}

      {:error, :invalid_status} ->
        {:noreply,
         put_flash(socket, :error, "The selected registration status is not supported.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(socket, :edit_registration_form, to_form(changeset, as: :edit_registration))}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to update this registration right now.")}
    end
  end

  def handle_event("cancel_registration", %{"id" => id}, socket) do
    registration = find_registration(socket, id)

    case registration &&
           Registrations.cancel_registration(
             socket.assigns.current_scope,
             registration,
             "Cancelled by the registration administrator."
           ) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration cancelled successfully.")
         |> assign(:editing_registration, nil)
         |> assign(:edit_registration_form, nil)
         |> load_registration_list()}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to cancel this registration right now.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="registrations"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Registration management"
          title="List of Registration"
        />

        <%= if is_nil(@selected_training) do %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Training directory"
              title="Choose a Training First"
            />

            <%= if @trainings == [] do %>
              <.portal_empty_state
                icon="hero-calendar-days"
                title="No trainings available yet"
                copy="Create a training activity first before managing registrations."
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
                    <tr :for={training <- @trainings}>
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
                          patch={training_management_path(training.id, @filters)}
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
          <.portal_stat_grid cards={@registration_summary_cards} />

          <%= if @manual_registration_open? do %>
            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Manual entry"
                title="Add Participants"
                meta="Enter one full name per line. User accounts and email addresses are optional."
              >
                <:actions>
                  <.button type="button" phx-click="cancel_manual_registration" variant="ghost">
                    Back to Registration List
                  </.button>
                </:actions>
              </.portal_panel_header>

              <.form
                for={@manual_registration_form}
                id="manual-registration-form"
                phx-change="validate_manual_registration"
                phx-submit="save_manual_registration"
              >
                <.input
                  field={@manual_registration_form[:participant_names]}
                  type="textarea"
                  label="Participant Names"
                  placeholder="1. Juan Cruz\n2. Ana Reyes\n3. Maria Santos"
                  rows="8"
                />

                <div class="mt-6 flex flex-wrap justify-end gap-3">
                  <.button type="button" phx-click="cancel_manual_registration" variant="ghost">
                    Close
                  </.button>
                  <.button phx-disable-with="Adding Participants...">Add Participants</.button>
                </div>
              </.form>
            </section>
          <% else %>
            <%= if @selected_registration do %>
              <section class="panel portal-list-panel">
                <.portal_panel_header
                  eyebrow="Participant information"
                  title={participant_name(@selected_registration)}
                  meta={registration_number(@selected_registration)}
                >
                  <:actions>
                    <.button type="button" phx-click="hide_registration" variant="ghost">
                      Back to Registration List
                    </.button>
                  </:actions>
                </.portal_panel_header>

                <div class="portal-resource-facts">
                  <div>
                    <span class="portal-fact-label">Email Address</span>
                    <span class="portal-fact-value">
                      {Registrations.participant_email(@selected_registration) || "Not provided"}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Contact Number</span>
                    <span class="portal-fact-value">{contact_number(@selected_registration)}</span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Organization</span>
                    <span class="portal-fact-value">
                      {organization_name(@selected_registration)}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Selected Training</span>
                    <span class="portal-fact-value">
                      {@selected_registration.training_activity.title}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Registration Date</span>
                    <span class="portal-fact-value">
                      {registration_date(@selected_registration)}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Current Workflow State</span>
                    <span class="portal-fact-value">
                      {Registrations.format_status(@selected_registration.status)}
                    </span>
                  </div>
                </div>

                <div class="mt-6 grid gap-6 lg:grid-cols-2">
                  <div class="feature-card">
                    <div class="feature-title">Registration Notes</div>
                    <div class="feature-copy">
                      {@selected_registration.review_notes || "No registration notes yet."}
                    </div>
                  </div>

                  <div class="feature-card">
                    <div class="feature-title">Special Requirements</div>
                    <div class="feature-copy">
                      {@selected_registration.special_requirements ||
                        "No special requirements provided."}
                    </div>
                  </div>
                </div>
              </section>
            <% else %>
              <div class="content-grid">
                <section class="panel portal-list-panel md:col-span-2">
                  <.form
                    for={to_form(@filters, as: :filters)}
                    id="registration-filters"
                    phx-change="filter"
                    class="certificate-records-controls mb-6 flex flex-wrap items-center gap-3"
                  >
                    <.input
                      field={to_form(@filters, as: :filters)[:search]}
                      type="search"
                      placeholder="Search participant"
                      aria-label="Search Participant"
                      class="field-input w-full sm:w-96 lg:w-[28rem]"
                    />
                    <div class="flex flex-wrap items-center gap-3">
                      <.button
                        type="button"
                        phx-click="show_manual_registration"
                        variant="secondary"
                      >
                        Add Participant Manually
                      </.button>
                      <.button href={registration_export_path(:excel, @filters)} variant="ghost">
                        Export Excel
                      </.button>
                      <.button href={registration_export_path(:pdf, @filters)} variant="ghost">
                        Export PDF
                      </.button>
                      <.button patch={~p"/registrations"} variant="ghost">
                        Back
                      </.button>
                    </div>
                  </.form>

                  <%= if @registrations == [] do %>
                    <.portal_empty_state
                      icon="hero-user-group"
                      title="No registrations found"
                      copy="There are no registration records matching the current search and filter selection."
                    />
                  <% else %>
                    <div class="data-table-wrap">
                      <table class="data-table">
                        <thead>
                          <tr>
                            <th>Registration Number</th>
                            <th>Participant Name</th>
                            <th>School, Office, or Organization</th>
                            <th>Selected Training</th>
                            <th>Registration Date</th>
                            <th>Action</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={registration <- @registrations}>
                            <td>
                              <span class="dashboard-cert-number">
                                {registration_number(registration)}
                              </span>
                            </td>
                            <td>
                              <div class="portal-cell-title">{participant_name(registration)}</div>
                              <div class="portal-cell-meta">
                                {participant_employee_number(registration)}
                              </div>
                            </td>
                            <td>{organization_name(registration)}</td>
                            <td>
                              <div class="portal-cell-title">
                                {registration.training_activity.title}
                              </div>
                              <div class="portal-cell-meta">
                                {format_date(registration.training_activity.starts_on)}
                              </div>
                            </td>
                            <td>{registration_date(registration)}</td>
                            <td>
                              <div class="portal-action-stack">
                                <.button
                                  type="button"
                                  phx-click="show_registration"
                                  phx-value-id={registration.id}
                                  variant="secondary"
                                >
                                  View
                                </.button>
                              </div>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  <% end %>

                  <p class="mt-4 text-right text-sm text-slate-500">{@registration_caption}</p>
                </section>

                <aside class="portal-panel-stack">
                  <section :if={@editing_registration} class="panel portal-list-panel">
                    <.portal_panel_header
                      eyebrow="Edit registration"
                      title="Update registration"
                      meta="Adjust the selected training, notes, or manager status for this record."
                    />

                    <.form
                      for={@edit_registration_form}
                      id="edit-registration-form"
                      phx-change="validate_edit_registration"
                      phx-submit="save_edit_registration"
                    >
                      <div class="grid gap-5">
                        <.input
                          field={@edit_registration_form[:training_activity_id]}
                          type="select"
                          label="Selected Training"
                          options={@training_options}
                        />
                        <.input
                          field={@edit_registration_form[:status]}
                          type="select"
                          label="Registration Status"
                          options={manager_status_options()}
                        />
                        <.input
                          field={@edit_registration_form[:special_requirements]}
                          type="textarea"
                          label="Special Requirements"
                          rows="3"
                        />
                        <.input
                          field={@edit_registration_form[:review_notes]}
                          type="textarea"
                          label="Registration Notes"
                          rows="4"
                        />
                      </div>

                      <div class="mt-6 flex flex-wrap justify-end gap-3">
                        <.button type="button" phx-click="cancel_edit_registration" variant="ghost">
                          Close
                        </.button>
                        <.button phx-disable-with="Saving Changes...">Save Changes</.button>
                      </div>
                    </.form>
                  </section>
                </aside>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_registration_list(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)
    selected_training = find_selected_training(trainings, socket.assigns.filters["training_id"])
    manage_view? = not is_nil(selected_training)

    registrations =
      if manage_view? do
        Registrations.list_manageable_registrations(
          socket.assigns.current_scope,
          socket.assigns.filters
        )
      else
        []
      end

    all_registrations =
      if manage_view? do
        Registrations.list_manageable_registrations(
          socket.assigns.current_scope,
          Map.put(socket.assigns.filters, "search", "")
        )
      else
        []
      end

    selected_registration =
      if manage_view? && socket.assigns.selected_registration do
        Enum.find(registrations, &(&1.id == socket.assigns.selected_registration.id))
      end

    editing_registration =
      if manage_view? && socket.assigns.editing_registration do
        Enum.find(registrations, &(&1.id == socket.assigns.editing_registration.id))
      end

    socket
    |> assign(:trainings, trainings)
    |> assign(:selected_training, selected_training)
    |> assign(:registrations, registrations)
    |> assign(:selected_registration, selected_registration)
    |> assign(:editing_registration, editing_registration)
    |> assign(:registration_caption, registration_caption(registrations))
    |> assign(
      :registration_summary_cards,
      registration_summary_cards(selected_training, all_registrations)
    )
    |> assign(:training_directory_caption, training_directory_caption(trainings))
    |> assign(:training_filter_options, training_filter_options(trainings))
    |> assign(:training_options, training_options(trainings))
    |> sync_management_state(manage_view?, editing_registration)
  end

  defp sync_management_state(socket, false, _editing_registration) do
    socket
    |> assign(:manual_registration_open?, false)
    |> assign_manual_form(default_manual_registration_params())
    |> assign(:edit_registration_form, nil)
  end

  defp sync_management_state(socket, true, editing_registration) do
    maybe_refresh_edit_form(socket, editing_registration)
  end

  defp maybe_refresh_edit_form(socket, nil) do
    assign(socket, :edit_registration_form, nil)
  end

  defp maybe_refresh_edit_form(socket, registration) do
    if socket.assigns.editing_registration do
      assign_edit_form(socket, registration)
    else
      socket
    end
  end

  defp assign_manual_form(socket, params) do
    assign(socket, :manual_registration_form, to_form(params, as: :manual_registration))
  end

  defp apply_manual_entry_mode(socket, "true") do
    if socket.assigns.selected_training do
      open_manual_registration(socket)
    else
      socket
    end
  end

  defp apply_manual_entry_mode(socket, _manual), do: socket

  defp open_manual_registration(socket) do
    socket
    |> assign(:manual_registration_open?, true)
    |> assign(:editing_registration, nil)
    |> assign(:selected_registration, nil)
    |> assign_manual_form(default_manual_registration_params())
  end

  defp assign_edit_form(socket, registration) do
    changeset =
      Registrations.change_manager_registration(registration, %{
        "training_activity_id" => registration.training_activity_id,
        "status" => manager_status_value(registration),
        "special_requirements" => registration.special_requirements,
        "review_notes" => registration.review_notes
      })

    assign(socket, :edit_registration_form, to_form(changeset, as: :edit_registration))
  end

  defp registration_caption(registrations) do
    count = length(registrations)
    "Showing #{count} #{if(count == 1, do: "registration", else: "registrations")}."
  end

  defp registration_summary_cards(nil, _registrations), do: []

  defp registration_summary_cards(training, registrations) do
    registered_count = Enum.count(registrations, &registered_status?/1)

    available_capacity =
      case training.max_capacity do
        nil -> "No Limit"
        max_capacity -> max(max_capacity - registered_count, 0)
      end

    [
      summary_card("Total Registrations", length(registrations), "All participant records"),
      summary_card("Registered", registered_count, "Active participant records"),
      summary_card("Available Capacity", available_capacity, "Remaining participant slots")
    ]
  end

  defp training_directory_caption(trainings) do
    count = length(trainings)
    "#{count} #{if(count == 1, do: "training", else: "trainings")} ready for registration review."
  end

  defp training_filter_options(trainings) do
    [{"All trainings", ""}] ++ Enum.map(trainings, &{&1.title, &1.id})
  end

  defp training_options(trainings) do
    Enum.map(trainings, &{&1.title, &1.id})
  end

  defp manager_status_options do
    [
      {"Registered", "submitted"},
      {"Cancelled", "withdrawn"}
    ]
  end

  defp participant_name(registration) do
    Registrations.participant_name(registration)
  end

  defp organization_name(registration) do
    Registrations.participant_organization(registration)
  end

  defp participant_employee_number(%{registrant_user: %{employee_number: employee_number}}),
    do: employee_number || "No employee number"

  defp participant_employee_number(_registration), do: "Guest participant"

  defp contact_number(_registration), do: "Not provided"

  defp registration_date(registration) do
    format_datetime(registration.submitted_at || registration.inserted_at)
  end

  defp manager_status_value(registration) do
    if registered_status?(registration), do: "submitted", else: "withdrawn"
  end

  defp registered_status?(registration) do
    registration.status in [:submitted, :approved, :waitlisted]
  end

  defp registration_number(registration) do
    suffix =
      registration.id
      |> String.replace("-", "")
      |> String.slice(-6, 6)
      |> String.upcase()

    "REG-#{suffix}"
  end

  defp normalize_edit_params(params) do
    %{
      "training_activity_id" => params["training_activity_id"],
      "status" => params["status"],
      "special_requirements" => params["special_requirements"],
      "review_notes" => params["review_notes"]
    }
  end

  defp default_manual_registration_params do
    %{"participant_names" => ""}
  end

  defp find_selected_training(_trainings, training_id) when training_id in [nil, ""], do: nil

  defp find_selected_training(trainings, training_id) do
    Enum.find(trainings, &(&1.id == training_id))
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

  defp training_management_path(training_id, filters) do
    query =
      filters
      |> Map.take(["search"])
      |> Map.put("training_id", training_id)
      |> Map.put("view", "manage")
      |> compact_filters()
      |> URI.encode_query()

    "/registrations?" <> query
  end

  defp registration_view_mode(training_id, _requested_view) when training_id in [nil, ""],
    do: :directory

  defp registration_view_mode(_training_id, _requested_view), do: :manage

  defp find_registration(socket, id) do
    Enum.find(socket.assigns.registrations, &(&1.id == id))
  end

  defp registration_export_path(format, filters) do
    query = URI.encode_query(compact_filters(filters))
    base = "/registrations/export/#{format}"
    if query == "", do: base, else: "#{base}?#{query}"
  end

  defp compact_filters(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
