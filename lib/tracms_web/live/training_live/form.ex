defmodule TracmsWeb.TrainingLive.Form do
  use TracmsWeb, :live_view

  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new ->
          training_activity = %TrainingActivity{}

          socket
          |> assign(:page_title, "Create Training")
          |> assign(:training_activity, training_activity)
          |> assign_form(Trainings.change_training_activity(training_activity))

        :edit ->
          training_activity =
            Trainings.get_training_activity!(socket.assigns.current_scope, params["id"])

          socket
          |> assign(:page_title, "Edit Training")
          |> assign(:training_activity, training_activity)
          |> assign_form(Trainings.change_training_activity(training_activity))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"training_activity" => training_params}, socket) do
    changeset =
      socket.assigns.training_activity
      |> Trainings.change_training_activity(training_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"training_activity" => training_params}, socket) do
    save_training_activity(socket, socket.assigns.live_action, training_params)
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
          eyebrow="Training management"
          title={@page_title}
          copy="Capture the full training record needed for registration, attendance, evaluation, reporting, and future certification workflows."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to list</.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <.form for={@form} id="training-form" phx-change="validate" phx-submit="save">
            <div class="portal-form-section">
              <.portal_panel_header
                eyebrow="Training profile"
                title="Basic information"
                meta="Record the official title, category, type, and narrative for the training."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <.input field={@form[:title]} type="text" label="Training title" />
                <.input
                  field={@form[:category]}
                  type="select"
                  label="Training category"
                  options={TrainingActivity.category_options()}
                />
                <.input
                  field={@form[:training_type]}
                  type="select"
                  label="Training type"
                  options={TrainingActivity.training_type_options()}
                />
                <.input field={@form[:organizer]} type="text" label="Implementing office" />
                <div class="md:col-span-2">
                  <.input
                    field={@form[:description]}
                    type="textarea"
                    label="Training description"
                    rows="6"
                  />
                </div>
                <div class="md:col-span-2">
                  <.input
                    field={@form[:objectives]}
                    type="textarea"
                    label="Training objectives"
                    rows="6"
                  />
                </div>
              </div>
            </div>

            <div class="portal-form-section">
              <.portal_panel_header
                eyebrow="Schedule and registration"
                title="Program schedule"
                meta="Define the date range, training hours, and registration window."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <.input field={@form[:starts_on]} type="date" label="Start date" />
                <.input field={@form[:ends_on]} type="date" label="End date" />
                <.input
                  field={@form[:total_hours]}
                  type="number"
                  label="Total training hours"
                  min="1"
                />
                <.input
                  field={@form[:max_capacity]}
                  type="number"
                  label="Target number of participants"
                  min="1"
                />
                <.input
                  field={@form[:registration_opens_on]}
                  type="date"
                  label="Registration opening date"
                />
                <.input
                  field={@form[:registration_deadline]}
                  type="datetime-local"
                  label="Registration deadline"
                />
              </div>
            </div>

            <div class="portal-form-section">
              <.portal_panel_header
                eyebrow="Venue and participants"
                title="Delivery context"
                meta="Capture where the training happens and who should attend."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <.input
                  field={@form[:modality]}
                  type="select"
                  label="Training modality"
                  options={TrainingActivity.modality_options()}
                />
                <.input field={@form[:venue]} type="text" label="Training venue" />
                <div class="md:col-span-2">
                  <.input field={@form[:venue_address]} type="text" label="Venue address" />
                </div>
                <div class="md:col-span-2">
                  <.input
                    field={@form[:target_participants]}
                    type="textarea"
                    label="Target participants"
                    rows="4"
                  />
                </div>
                <div class="md:col-span-2">
                  <.input
                    field={@form[:participant_qualification]}
                    type="textarea"
                    label="Participant qualification"
                    rows="4"
                  />
                </div>
              </div>
            </div>

            <div class="portal-form-section">
              <.portal_panel_header
                eyebrow="Attendance and certificate"
                title="Completion requirements"
                meta="Set the operational rules used later by attendance, evaluation, and certification."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <.input
                  field={@form[:attendance_monitoring_method]}
                  type="select"
                  label="Attendance monitoring method"
                  options={TrainingActivity.attendance_monitoring_method_options()}
                />
                <.input
                  field={@form[:certificate_type]}
                  type="select"
                  label="Certificate type"
                  options={TrainingActivity.certificate_type_options()}
                />
                <.input
                  field={@form[:minimum_attendance_percentage]}
                  type="number"
                  label="Minimum attendance percentage"
                  min="0"
                  max="100"
                />
                <.input
                  field={@form[:evaluation_required]}
                  type="checkbox"
                  label="Require participant evaluation before completion"
                />
              </div>
            </div>

            <div class="mt-6 flex flex-wrap justify-end gap-3">
              <.button navigate={~p"/trainings"} variant="ghost">Cancel</.button>
              <.button>
                {if @live_action == :new, do: "Create training", else: "Save changes"}
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp save_training_activity(socket, :new, training_params) do
    case Trainings.create_training_activity(socket.assigns.current_scope, training_params) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity created successfully.")
         |> push_navigate(to: ~p"/trainings/#{training_activity.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You do not have permission to create training activities.")
         |> push_navigate(to: ~p"/trainings")}
    end
  end

  defp save_training_activity(socket, :edit, training_params) do
    case Trainings.update_training_activity(
           socket.assigns.current_scope,
           socket.assigns.training_activity,
           training_params
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity updated successfully.")
         |> push_navigate(to: ~p"/trainings/#{training_activity.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "This training activity can no longer be edited.")
         |> push_navigate(to: ~p"/trainings/#{socket.assigns.training_activity.id}")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
