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
      <div class="space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="eyebrow">Training management</p>
            <h1 class="section-title">{@page_title}</h1>
          </div>
          <.button navigate={~p"/trainings"} variant="ghost">Back to list</.button>
        </div>

        <section class="panel">
          <.form for={@form} id="training-form" phx-change="validate" phx-submit="save">
            <div class="grid gap-5 md:grid-cols-2">
              <.input field={@form[:title]} type="text" label="Training title" />
              <.input field={@form[:category]} type="text" label="Category" />
              <.input field={@form[:organizer]} type="text" label="Organizer" />
              <.input
                field={@form[:modality]}
                type="select"
                label="Modality"
                options={TrainingActivity.modality_options()}
              />
              <.input field={@form[:venue]} type="text" label="Venue" />
              <.input field={@form[:max_capacity]} type="number" label="Maximum capacity" min="1" />
              <.input field={@form[:starts_on]} type="date" label="Start date" />
              <.input field={@form[:ends_on]} type="date" label="End date" />
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
              <div class="md:col-span-2">
                <.input
                  field={@form[:registration_deadline]}
                  type="datetime-local"
                  label="Registration deadline"
                />
              </div>
              <div class="md:col-span-2">
                <.input field={@form[:description]} type="textarea" label="Description" rows="8" />
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
