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
      <div class="space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="eyebrow">Training details</p>
            <h1 class="section-title">{@training_activity.title}</h1>
            <p class="section-copy">{@training_activity.category}</p>
          </div>
          <div class="flex flex-wrap gap-3">
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
              :if={Trainings.editable?(@training_activity)}
              navigate={~p"/trainings/#{@training_activity.id}/edit"}
              variant="secondary"
            >
              Edit training
            </.button>
            <.button :if={@next_action_label} phx-click="advance">{@next_action_label}</.button>
          </div>
        </div>

        <div class="content-grid">
          <section class="panel">
            <p class="eyebrow">Overview</p>
            <div class="space-y-4">
              <div>
                <h2 class="section-title">Description</h2>
                <p class="section-copy whitespace-pre-line">{@training_activity.description}</p>
              </div>

              <div class="grid gap-4 md:grid-cols-2">
                <div class="feature-card">
                  <div class="feature-title">Organizer</div>
                  <div class="feature-copy">{@training_activity.organizer}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Venue</div>
                  <div class="feature-copy">{@training_activity.venue}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Modality</div>
                  <div class="feature-copy">
                    {@training_activity.modality
                    |> Atom.to_string()
                    |> String.replace("_", " ")
                    |> String.capitalize()}
                  </div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Status</div>
                  <div class="feature-copy">{Trainings.format_status(@training_activity.status)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Minimum attendance</div>
                  <div class="feature-copy">
                    {@training_activity.minimum_attendance_percentage}%
                  </div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Evaluation required</div>
                  <div class="feature-copy">
                    {if @training_activity.evaluation_required, do: "Yes", else: "No"}
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="panel">
            <p class="eyebrow">Schedule and ownership</p>
            <div class="space-y-4">
              <div class="feature-card">
                <div class="feature-title">Training dates</div>
                <div class="feature-copy">
                  {@training_activity.starts_on} to {@training_activity.ends_on}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Registration deadline</div>
                <div class="feature-copy">{@training_activity.registration_deadline}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Maximum capacity</div>
                <div class="feature-copy">{@training_activity.max_capacity}</div>
              </div>
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
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
