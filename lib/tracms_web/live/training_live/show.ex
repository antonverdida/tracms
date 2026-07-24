defmodule TracmsWeb.TrainingLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    training_activity = Trainings.get_training_activity!(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign(:page_title, training_activity.title)
     |> assign(:training_activity, training_activity)
     |> assign(
       :next_action_label,
       Trainings.next_action_label(socket.assigns.current_scope, training_activity)
     )}
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
         |> assign(:training_activity, training_activity)
         |> assign(
           :next_action_label,
           Trainings.next_action_label(socket.assigns.current_scope, training_activity)
         )}

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
            <.button :if={@next_action_label} phx-click="advance">{@next_action_label}</.button>
          </:actions>
        </.portal_page_header>

        <div class="content-grid">
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
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Ownership"
              title="Management context"
              meta="DepEd ownership and record custody information."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Owning office</div>
                <div class="feature-copy">
                  {(@training_activity.office && @training_activity.office.name) || "Not set"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Owning division</div>
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
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_publication_date(nil), do: "Not yet published"
  defp format_publication_date(datetime), do: format_datetime(datetime)

  defp duration_days(training_activity) do
    Date.diff(training_activity.ends_on, training_activity.starts_on) + 1
  end
end
