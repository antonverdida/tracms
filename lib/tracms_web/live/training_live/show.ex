defmodule TracmsWeb.TrainingLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
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
  def handle_event("validate_certificate_layout", %{"training_activity" => params}, socket) do
    changeset =
      socket.assigns.training_activity
      |> Trainings.change_training_certificate_layout(params)
      |> Map.put(:action, :validate)

    preview_training = Ecto.Changeset.apply_changes(changeset)

    {:noreply,
     socket
     |> assign(:certificate_layout_form, to_form(changeset))
     |> assign(
       :certificate_layout_preview,
       Certificates.effective_layout_settings(preview_training)
     )
     |> assign(
       :certificate_layout_preview_certificate,
       Certificates.sample_preview_certificate(preview_training)
     )}
  end

  def handle_event("save_certificate_layout", %{"training_activity" => params}, socket) do
    case Trainings.update_training_certificate_layout(
           socket.assigns.current_scope,
           socket.assigns.training_activity,
           params
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Certificate layout updated for this training.")
         |> load_page(training_activity.id)}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to update this training layout.")}

      {:error, changeset} ->
        preview_training = Ecto.Changeset.apply_changes(changeset)

        {:noreply,
         socket
         |> assign(:certificate_layout_form, to_form(changeset, action: :validate))
         |> assign(
           :certificate_layout_preview,
           Certificates.effective_layout_settings(preview_training)
         )
         |> assign(
           :certificate_layout_preview_certificate,
           Certificates.sample_preview_certificate(preview_training)
         )}
    end
  end

  def handle_event("reset_certificate_layout", _params, socket) do
    case Trainings.reset_training_certificate_layout(
           socket.assigns.current_scope,
           socket.assigns.training_activity
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training certificate layout reset to the default design.")
         |> load_page(training_activity.id)}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to reset this training layout.")}
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
          copy="Review the main details and workflow for this training record."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to trainings</.button>
            <.button
              :if={Trainings.editable?(@training_activity)}
              navigate={~p"/trainings/#{@training_activity.id}/edit"}
              variant="secondary"
            >
              Edit
            </.button>
          </:actions>
        </.portal_page_header>

        <div class="content-grid">
          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header
              eyebrow="Overview"
              title="Government training record"
              meta="Key details for this training record."
            />

            <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              <.detail_item label="Status">
                <span class={[
                  "portal-chip",
                  "portal-chip-#{training_status_tone(@training_activity.status)}"
                ]}>
                  {Trainings.format_status(@training_activity.status)}
                </span>
              </.detail_item>

              <.detail_item label="Schedule">
                {format_date(@training_activity.starts_on)} to {format_date(
                  @training_activity.ends_on
                )}
              </.detail_item>

              <.detail_item label="Registration Deadline">
                {format_datetime(@training_activity.registration_deadline)}
              </.detail_item>

              <.detail_item label="Modality">
                {format_modality(@training_activity.modality)}
              </.detail_item>

              <.detail_item label="Venue">
                {display_value(@training_activity.venue)}
              </.detail_item>

              <.detail_item label="Capacity">
                {@training_activity.max_capacity} participants
              </.detail_item>

              <.detail_item label="Collection Model">
                {collection_mode_label(@training_activity)}
              </.detail_item>

              <.detail_item label="Duration">
                {duration_days(@training_activity)} day(s) • {@training_activity.total_hours} hour(s)
              </.detail_item>

              <.detail_item label="Google Workspace integration">
                <.link
                  navigate={~p"/trainings/#{@training_activity.id}/integrations"}
                  class="portal-inline-action"
                >
                  Open integration module
                </.link>
              </.detail_item>
            </div>
          </section>

          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header
              eyebrow="Description"
              title="Training Narrative"
              meta="Official description, objectives, and participant context for this activity."
            />

            <div class="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(20rem,0.8fr)]">
              <div class="space-y-5">
                <.narrative_block title="Description">
                  {display_value(@training_activity.description, "No description provided.")}
                </.narrative_block>

                <.narrative_block title="Objectives">
                  {display_value(@training_activity.objectives, "No objectives provided.")}
                </.narrative_block>
              </div>

              <div class="rounded-2xl border border-slate-200 bg-slate-50 px-5 py-5">
                <p class="text-[0.72rem] font-extrabold tracking-[0.18em] text-slate-500 uppercase">
                  Participant Context
                </p>
                <div class="mt-4 grid gap-4">
                  <.detail_item label="Target Participants">
                    {display_value(@training_activity.target_participants, "Not specified.")}
                  </.detail_item>
                  <.detail_item label="Participant Qualification">
                    {display_value(@training_activity.participant_qualification, "Not specified.")}
                  </.detail_item>
                </div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header
              eyebrow="Certificate layout"
              title="Per-Training Certificate Design"
              meta="Saved changes apply to preview, print, and export."
            />

            <div class="grid gap-6 xl:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)]">
              <div class="portal-form-section">
                <div class="mb-5 grid gap-4 md:grid-cols-2">
                  <.detail_item label="Current Layout">
                    {if @certificate_layout_custom?, do: "Custom override", else: "Using default"}
                  </.detail_item>
                  <.detail_item label="Applies To">
                    Preview, print, and export
                  </.detail_item>
                </div>

                <.form
                  for={@certificate_layout_form}
                  id="training_certificate_layout_form"
                  phx-submit="save_certificate_layout"
                  phx-change="validate_certificate_layout"
                >
                  <div class="grid gap-4 md:grid-cols-2">
                    <.input
                      field={@certificate_layout_form[:certificate_layout_style]}
                      type="select"
                      label="Layout style"
                      options={[{"Use default", ""} | Certificates.certificate_layout_style_options()]}
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_accent_color]}
                      type="select"
                      label="Accent color"
                      options={[{"Use default", ""} | Certificates.certificate_accent_color_options()]}
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_header_title]}
                      type="text"
                      label="Header title"
                      placeholder="Use default"
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_header_subtitle]}
                      type="text"
                      label="Header subtitle"
                      placeholder="Use default"
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_signature_label]}
                      type="text"
                      label="Signature label"
                      placeholder="Use default"
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_issuing_office_label]}
                      type="text"
                      label="Issuing office label"
                      placeholder="Use default"
                    />
                  </div>

                  <div class="mt-4 grid gap-4">
                    <.input
                      field={@certificate_layout_form[:certificate_body_intro]}
                      type="textarea"
                      label="Body introduction"
                      rows="3"
                      placeholder="Use default"
                    />
                    <.input
                      field={@certificate_layout_form[:certificate_completion_statement]}
                      type="textarea"
                      label="Completion statement"
                      rows="4"
                      placeholder="Use default"
                    />
                  </div>

                  <div class="mt-4 flex flex-wrap justify-end gap-3">
                    <.button
                      :if={@certificate_layout_custom?}
                      type="button"
                      variant="secondary"
                      phx-click="reset_certificate_layout"
                    >
                      Reset to default
                    </.button>
                    <.button variant="primary" phx-disable-with="Saving...">
                      Save training layout
                    </.button>
                  </div>
                </.form>
              </div>

              <div class="certificate-sample-shell">
                <.portal_panel_header
                  eyebrow="Preview"
                  title="Training Certificate Preview"
                />

                <.certificate_sheet
                  certificate={@certificate_layout_preview_certificate}
                  participant_name={
                    certificate_participant_name(@certificate_layout_preview_certificate)
                  }
                  issued_by_name={certificate_issued_by_name(@certificate_layout_preview_certificate)}
                  layout_settings={@certificate_layout_preview}
                />
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket, training_id) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    socket
    |> assign(:page_title, training_activity.title)
    |> assign(:training_activity, training_activity)
    |> assign(
      :certificate_layout_custom?,
      Certificates.custom_layout_override?(training_activity)
    )
    |> assign(
      :certificate_layout_form,
      to_form(Trainings.change_training_certificate_layout(training_activity))
    )
    |> assign(
      :certificate_layout_preview,
      Certificates.effective_layout_settings(training_activity)
    )
    |> assign(
      :certificate_layout_preview_certificate,
      Certificates.sample_preview_certificate(training_activity)
    )
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp detail_item(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-slate-50 px-5 py-4">
      <p class="text-[0.72rem] font-extrabold tracking-[0.18em] text-slate-500 uppercase">
        {@label}
      </p>
      <div class="mt-2 text-sm font-semibold leading-6 text-slate-900">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp narrative_block(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-slate-50 px-5 py-4">
      <h2 class="text-base font-semibold text-slate-900">{@title}</h2>
      <p class="mt-2 whitespace-pre-line text-sm leading-7 text-slate-600">
        {render_slot(@inner_block)}
      </p>
    </div>
    """
  end

  defp collection_mode_label(training_activity) do
    if training_activity.registration_form_url || training_activity.attendance_form_url do
      "External form workflow"
    else
      "TRACMS portal workflow"
    end
  end

  defp display_value(value, fallback \\ "Not set")

  defp display_value(nil, fallback), do: fallback

  defp display_value(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      normalized_value -> normalized_value
    end
  end

  defp display_value(value, _fallback), do: value

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> "green"
      status in [:draft, :pending_division_approval, :pending_region_approval] -> "amber"
      status in [:completed, :archived] -> "blue"
      true -> "slate"
    end
  end

  defp duration_days(training_activity) do
    Date.diff(training_activity.ends_on, training_activity.starts_on) + 1
  end
end
