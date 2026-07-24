defmodule TracmsWeb.TrainingLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Evaluations
  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply, load_page(socket, id)}
  end

  @impl true
  def handle_event("advance", _params, socket) do
    case Trainings.advance_training_activity(
           socket.assigns.current_scope,
           socket.assigns.training_activity
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity status updated successfully.")
         |> load_page(training_activity.id)}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This training activity cannot advance from its current state."
         )}
    end
  end

  @impl true
  def handle_event("validate_return", %{"workflow_review" => params}, socket) do
    {:noreply, assign(socket, :workflow_review_form, to_form(params, as: :workflow_review))}
  end

  def handle_event(
        "return_for_revision",
        %{"workflow_review" => %{"notes" => notes} = params},
        socket
      ) do
    case Trainings.return_training_activity_for_revision(
           socket.assigns.current_scope,
           socket.assigns.training_activity,
           notes
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity returned for revision.")
         |> load_page(training_activity.id)}

      {:error, :missing_notes} ->
        {:noreply,
         socket
         |> put_flash(:error, "Provide a revision note before returning this record.")
         |> assign(:workflow_review_form, to_form(params, as: :workflow_review))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You cannot return this training record.")}

      {:error, :invalid_transition} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This training record is not in a returnable approval stage."
         )}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket
         |> put_flash(:error, "The revision note could not be saved.")
         |> assign(:workflow_review_form, to_form(params, as: :workflow_review))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="trainings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Training details"
          title={@training_activity.title}
          copy={"#{@training_activity.category} • #{@training_activity.training_type}"}
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to list</.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/integrations"} variant="ghost">
              Google Workspace
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/registrations"} variant="ghost">
              View registrations
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/attendance"} variant="ghost">
              Attendance
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/completion"} variant="ghost">
              Completion
            </.button>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/certificates"}
              variant="ghost"
            >
              Certificates
            </.button>
            <.button
              :if={Trainings.editable?(@training_activity)}
              navigate={~p"/trainings/#{@training_activity.id}/edit"}
              variant="secondary"
            >
              Edit training
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <div class="content-grid">
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Training identification"
              title="Government training record"
              meta="Core record fields used for reporting, attendance, completion, and certification workflows."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Record reference</div>
                <div class="feature-copy">{training_reference(@training_activity)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Training category</div>
                <div class="feature-copy">{@training_activity.category}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Training type</div>
                <div class="feature-copy">{@training_activity.training_type}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Training provider</div>
                <div class="feature-copy">{@training_activity.organizer}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Attendance method</div>
                <div class="feature-copy">{@training_activity.attendance_monitoring_method}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Certificate output</div>
                <div class="feature-copy">{@training_activity.certificate_type}</div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Overview"
              title="Training narrative"
              meta="Official description and objectives for this activity."
            />

            <div class="space-y-5">
              <div>
                <h2 class="section-title">Description</h2>
                <p class="section-copy whitespace-pre-line">{@training_activity.description}</p>
              </div>

              <div>
                <h2 class="section-title">Objectives</h2>
                <p class="section-copy whitespace-pre-line">{@training_activity.objectives}</p>
              </div>

              <div class="grid gap-4 md:grid-cols-2">
                <div class="feature-card">
                  <div class="feature-title">Implementing office</div>
                  <div class="feature-copy">{@training_activity.organizer}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Training type</div>
                  <div class="feature-copy">{@training_activity.training_type}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Modality</div>
                  <div class="feature-copy">{format_modality(@training_activity.modality)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Status</div>
                  <div class="feature-copy">{Trainings.format_status(@training_activity.status)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Target participants</div>
                  <div class="feature-copy whitespace-pre-line">
                    {@training_activity.target_participants}
                  </div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Participant qualification</div>
                  <div class="feature-copy whitespace-pre-line">
                    {@training_activity.participant_qualification}
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Schedule and delivery"
              title="Program record"
              meta="Operational settings used by registration, attendance, evaluation, and reporting."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Training schedule</div>
                <div class="feature-copy">
                  {format_date(@training_activity.starts_on)} to {format_date(
                    @training_activity.ends_on
                  )}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Duration</div>
                <div class="feature-copy">
                  {duration_days(@training_activity)} day(s) • {@training_activity.total_hours} hour(s)
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Registration period</div>
                <div class="feature-copy">
                  Opens {format_date(@training_activity.registration_opens_on)} • closes {format_datetime(
                    @training_activity.registration_deadline
                  )}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Collection model</div>
                <div class="feature-copy">{collection_mode_label(@training_activity)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Maximum capacity</div>
                <div class="feature-copy">{@training_activity.max_capacity} participants</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Training venue</div>
                <div class="feature-copy">{@training_activity.venue}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Venue address</div>
                <div class="feature-copy">{@training_activity.venue_address}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Attendance monitoring</div>
                <div class="feature-copy">{@training_activity.attendance_monitoring_method}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Certificate type</div>
                <div class="feature-copy">{@training_activity.certificate_type}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Minimum attendance</div>
                <div class="feature-copy">
                  {@training_activity.minimum_attendance_percentage}% of total training hours
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Evaluation required</div>
                <div class="feature-copy">
                  {if @training_activity.evaluation_required, do: "Yes", else: "No"}
                </div>
              </div>
              <div class="feature-card md:col-span-2">
                <div class="feature-title">Google Workspace integration</div>
                <div class="feature-copy">
                  Manage registration and attendance forms, response sheets, and sync readiness in the dedicated integration module for this training.
                </div>
                <div class="mt-3">
                  <.button
                    navigate={~p"/trainings/#{@training_activity.id}/integrations"}
                    variant="secondary"
                  >
                    Open integration module
                  </.button>
                </div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Workflow status"
              title="Training workflow"
              meta="Current release status and the standard TRACMS government approval path."
            />

            <div class="portal-workflow-list">
              <div
                :for={item <- @workflow_items}
                class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
              >
                <div>
                  <p class="portal-workflow-label">{item.label}</p>
                  <p class="portal-workflow-copy">{item.description}</p>
                </div>
                <span class="portal-workflow-value">{item.value}</span>
              </div>
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Current status</div>
                <div class="feature-copy">
                  {Trainings.format_status(@training_activity.status)}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Next workflow action</div>
                <div class="feature-copy">{@next_action_label || "No action available"}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Record owner</div>
                <div class="feature-copy">
                  {(@training_activity.office && @training_activity.office.name) || "Not set"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Division context</div>
                <div class="feature-copy">
                  {(@training_activity.division && @training_activity.division.name) || "Not set"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Created by</div>
                <div class="feature-copy">
                  {(@training_activity.creator_user && @training_activity.creator_user.email) ||
                    "System"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Published at</div>
                <div class="feature-copy">
                  {format_publication_date(@training_activity.published_at)}
                </div>
              </div>
            </div>

            <section
              :if={@next_action_label || @return_action_label}
              class="mt-6 rounded-3xl border border-[rgba(18,58,104,0.08)] bg-white/80 p-5 shadow-sm"
            >
              <div class="space-y-4">
                <div>
                  <h3 class="section-title">Workflow actions</h3>
                  <p class="section-copy">
                    Continue the approval flow here or return the training record to draft for revision.
                  </p>
                </div>

                <.form
                  for={@workflow_review_form}
                  id="workflow-review-form"
                  phx-change="validate_return"
                  phx-submit="return_for_revision"
                >
                  <div class="grid gap-4">
                    <.input
                      :if={@return_action_label}
                      field={@workflow_review_form[:notes]}
                      type="textarea"
                      label="Revision note"
                      rows="4"
                    />

                    <div class="flex flex-wrap justify-end gap-3">
                      <.button
                        :if={@return_action_label}
                        type="submit"
                        variant="secondary"
                      >
                        {@return_action_label}
                      </.button>
                      <.button
                        :if={@next_action_label}
                        type="button"
                        phx-click="advance"
                      >
                        {@next_action_label}
                      </.button>
                    </div>
                  </div>
                </.form>
              </div>
            </section>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Approval history"
              title="Workflow audit trail"
              meta={approval_caption(@approval_entries)}
            />

            <%= if @approval_entries == [] do %>
              <.portal_empty_state
                icon="hero-clipboard-document-list"
                title="No workflow history yet"
                copy="Training creation and approval events will appear here as soon as they are recorded."
              />
            <% else %>
              <div class="portal-workflow-list">
                <div
                  :for={entry <- @approval_entries}
                  class={[
                    "portal-workflow-item",
                    "portal-workflow-item-#{approval_tone(entry.action)}"
                  ]}
                >
                  <div>
                    <p class="portal-workflow-label">{approval_title(entry)}</p>
                    <p class="portal-workflow-copy">
                      {approval_actor(entry)} • {approval_status_copy(entry)}
                    </p>
                    <p :if={entry.notes} class="portal-workflow-copy">Note: {entry.notes}</p>
                    <p class="portal-workflow-copy">{format_datetime(entry.inserted_at)}</p>
                  </div>
                  <span class="portal-workflow-value">
                    {approval_role_label(entry.actor_role_key)}
                  </span>
                </div>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket, training_id) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    registrations =
      Registrations.list_training_registrations(socket.assigns.current_scope, training_id)

    attendance_sessions = Attendance.list_sessions(socket.assigns.current_scope, training_id)

    certificates =
      Certificates.list_training_certificates(socket.assigns.current_scope, training_id)

    completion_entries =
      Evaluations.list_training_completion(socket.assigns.current_scope, training_id)

    approval_entries =
      Trainings.list_training_approvals(socket.assigns.current_scope, training_id)

    socket
    |> assign(:page_title, training_activity.title)
    |> assign(:training_activity, training_activity)
    |> assign(
      :next_action_label,
      Trainings.next_action_label(socket.assigns.current_scope, training_activity)
    )
    |> assign(
      :return_action_label,
      Trainings.return_action_label(socket.assigns.current_scope, training_activity)
    )
    |> assign(
      :summary_cards,
      summary_cards(
        training_activity,
        registrations,
        attendance_sessions,
        certificates,
        completion_entries
      )
    )
    |> assign(:workflow_items, workflow_items(training_activity))
    |> assign(:approval_entries, approval_entries)
    |> assign(:workflow_review_form, to_form(%{"notes" => ""}, as: :workflow_review))
  end

  defp summary_cards(
         training_activity,
         registrations,
         attendance_sessions,
         certificates,
         completion_entries
       ) do
    [
      summary_card(
        "Status",
        Trainings.format_status(training_activity.status),
        "Current lifecycle stage for this training record"
      ),
      summary_card(
        "Approved participants",
        Enum.count(registrations, &(&1.status == :approved)),
        "Participants cleared for attendance and completion tracking"
      ),
      summary_card(
        "Attendance sessions",
        length(attendance_sessions),
        "Recorded operational attendance windows"
      ),
      summary_card(
        "Certificates",
        length(certificates),
        "#{Enum.count(completion_entries, &(&1.completion_status == :completed))} participants currently meeting completion rules"
      )
    ]
  end

  defp workflow_items(training_activity) do
    current_index = workflow_index(training_activity.status)

    workflow_stages()
    |> Enum.with_index()
    |> Enum.map(fn {status, index} ->
      %{
        label: Trainings.format_status(status),
        description: workflow_description(status),
        value: workflow_value(index, current_index),
        tone: workflow_tone(index, current_index)
      }
    end)
  end

  defp workflow_stages do
    [
      :draft,
      :pending_division_approval,
      :pending_region_approval,
      :published,
      :registration_closed,
      :in_progress,
      :completed,
      :archived
    ]
  end

  defp workflow_index(status) do
    Enum.find_index(workflow_stages(), &(&1 == status)) || 0
  end

  defp workflow_value(index, current_index) when index < current_index, do: "Completed"
  defp workflow_value(index, current_index) when index == current_index, do: "Current"
  defp workflow_value(index, current_index) when index == current_index + 1, do: "Next"
  defp workflow_value(_index, _current_index), do: "Pending"

  defp workflow_tone(index, current_index) when index < current_index, do: "green"
  defp workflow_tone(index, current_index) when index == current_index, do: "blue"
  defp workflow_tone(index, current_index) when index == current_index + 1, do: "amber"
  defp workflow_tone(_index, _current_index), do: "slate"

  defp workflow_description(:draft), do: "Initial record preparation and internal encoding."

  defp workflow_description(:pending_division_approval),
    do: "Waiting for division-level review and endorsement."

  defp workflow_description(:pending_region_approval),
    do: "Waiting for region-level release approval."

  defp workflow_description(:published), do: "Approved and visible for registration activity."

  defp workflow_description(:registration_closed),
    do: "Registration window has ended for this activity."

  defp workflow_description(:in_progress),
    do: "Training delivery and attendance operations are ongoing."

  defp workflow_description(:completed),
    do: "Delivery is finished and completion checks are active."

  defp workflow_description(:archived),
    do: "Record is retained for reporting and historical reference."

  defp training_reference(training_activity) do
    year = training_activity.inserted_at.year

    suffix =
      training_activity.id
      |> String.replace("-", "")
      |> String.slice(0, 6)
      |> String.upcase()

    "TRACMS-#{year}-#{suffix}"
  end

  defp collection_mode_label(training_activity) do
    if training_activity.registration_form_url || training_activity.attendance_form_url do
      "External form workflow"
    else
      "TRACMS portal workflow"
    end
  end

  defp approval_caption(approval_entries) do
    count = length(approval_entries)
    "Showing #{count} recorded workflow #{if(count == 1, do: "event", else: "events")}."
  end

  defp approval_title(%{action: :created}), do: "Training record created"
  defp approval_title(%{action: :submitted_to_division}), do: "Submitted to division approval"
  defp approval_title(%{action: :submitted_to_region}), do: "Submitted to region approval"
  defp approval_title(%{action: :advanced_to_region_approval}), do: "Advanced to region approval"
  defp approval_title(%{action: :published}), do: "Training published"
  defp approval_title(%{action: :returned_for_revision}), do: "Returned for revision"
  defp approval_title(_entry), do: "Workflow event recorded"

  defp approval_actor(%{acted_by_user: %{full_name: full_name, email: email}}) do
    full_name || email
  end

  defp approval_actor(%{acted_by_user: %{email: email}}), do: email
  defp approval_actor(_entry), do: "System"

  defp approval_status_copy(%{from_status: nil, to_status: to_status}) do
    "Initial status set to #{Trainings.format_status(to_status)}"
  end

  defp approval_status_copy(%{from_status: from_status, to_status: to_status}) do
    "#{Trainings.format_status(from_status)} to #{Trainings.format_status(to_status)}"
  end

  defp approval_role_label("training_coordinator"), do: "Coordinator"
  defp approval_role_label("division_admin"), do: "Division Admin"
  defp approval_role_label("regional_admin"), do: "Regional Admin"
  defp approval_role_label(_role_key), do: "System"

  defp approval_tone(:created), do: "blue"
  defp approval_tone(:submitted_to_division), do: "amber"
  defp approval_tone(:submitted_to_region), do: "amber"
  defp approval_tone(:advanced_to_region_approval), do: "green"
  defp approval_tone(:published), do: "green"
  defp approval_tone(:returned_for_revision), do: "rose"
  defp approval_tone(_action), do: "slate"

  defp format_publication_date(nil), do: "Not yet published"
  defp format_publication_date(datetime), do: format_datetime(datetime)

  defp duration_days(training_activity) do
    Date.diff(training_activity.ends_on, training_activity.starts_on) + 1
  end
end
