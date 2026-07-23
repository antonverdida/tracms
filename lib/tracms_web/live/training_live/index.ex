defmodule TracmsWeb.TrainingLive.Index do
  use TracmsWeb, :live_view

  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Training Activities")
     |> assign(:trainings, Trainings.list_training_activities(socket.assigns.current_scope))}
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
        <.header>
          Training Activities
          <:subtitle>
            Create, review, and monitor training activities for DepEd Region IX.
          </:subtitle>
          <:actions>
            <.button navigate={~p"/trainings/new"}>Create training</.button>
          </:actions>
        </.header>

        <%= if @trainings == [] do %>
          <section class="panel">
            <h2 class="section-title">No training activities yet</h2>
            <p class="section-copy">
              Start by creating the first training activity for your office or division.
            </p>
          </section>
        <% else %>
          <section class="panel space-y-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p class="eyebrow">Current records</p>
                <h2 class="section-title">Managed trainings</h2>
              </div>
              <p class="text-sm text-[var(--tracms-text-muted)]">
                Showing {@trainings |> length()} training {if length(@trainings) == 1,
                  do: "activity",
                  else: "activities"}.
              </p>
            </div>

            <.table id="training-activities" rows={@trainings}>
              <:col :let={training} label="Title">
                <div class="font-semibold">{training.title}</div>
                <div class="text-sm text-[var(--tracms-text-muted)]">{training.category}</div>
              </:col>
              <:col :let={training} label="Schedule">
                <div>{training.starts_on}</div>
                <div class="text-sm text-[var(--tracms-text-muted)]">to {training.ends_on}</div>
              </:col>
              <:col :let={training} label="Registration">
                <div>{training.registration_deadline}</div>
              </:col>
              <:col :let={training} label="Modality">
                {training.modality
                |> Atom.to_string()
                |> String.replace("_", " ")
                |> String.capitalize()}
              </:col>
              <:col :let={training} label="Status">
                <span class="badge-soft">{Trainings.format_status(training.status)}</span>
              </:col>
              <:action :let={training}>
                <.link navigate={~p"/trainings/#{training.id}"} class="nav-link">View</.link>
              </:action>
              <:action :let={training}>
                <.link
                  :if={Trainings.editable?(training)}
                  navigate={~p"/trainings/#{training.id}/edit"}
                  class="nav-link"
                >
                  Edit
                </.link>
              </:action>
            </.table>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
