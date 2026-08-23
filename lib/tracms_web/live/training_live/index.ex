defmodule TracmsWeb.TrainingLive.Index do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Trainings

  @certificate_asset_accept ~w(.png .jpg .jpeg .webp .svg)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Training Activities")
     |> load_trainings()
     |> assign_saved_certificate_layout(Certificates.get_default_certificate_layout_setting())
     |> allow_upload(:certificate_layout_asset,
       accept: @certificate_asset_accept,
       max_entries: 1,
       max_file_size: 8_000_000
     )}
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
          title="Training Activities"
        >
          <:actions>
            <.button navigate={~p"/trainings/new"} variant="secondary">Add Training</.button>
          </:actions>
        </.portal_page_header>

        <section
          :if={false}
          class="panel portal-list-panel"
        >
          <.portal_panel_header
            eyebrow="Certificates"
            title="Certificate Layout"
            meta="Set the default certificate size and background used across training records."
          />

          <.form
            for={@certificate_layout_form}
            id="certificate-layout-form"
            phx-submit="update_certificate_layout"
            phx-change="validate_certificate_layout"
            class="portal-form-section"
          >
            <div class="grid gap-5 lg:grid-cols-2">
              <.input
                field={@certificate_layout_form[:certificate_size]}
                type="select"
                label="Certificate Size"
                options={Certificates.certificate_size_options()}
              />

              <div>
                <label class="block text-sm font-semibold text-[var(--tracms-text)]">
                  Certificate Background
                </label>
                <.live_file_input
                  upload={@uploads.certificate_layout_asset}
                  class="mt-2 block w-full text-sm text-[var(--tracms-text-muted)] file:mr-4 file:cursor-pointer file:rounded-full file:border-0 file:bg-[var(--tracms-primary)] file:px-5 file:py-2.5 file:text-sm file:font-semibold file:text-white file:shadow-[0_14px_30px_rgba(0,51,102,0.16)] hover:file:bg-[var(--tracms-primary-strong)]"
                />
                <p class="mt-2 text-sm text-[var(--tracms-text-muted)]">
                  PNG, JPG, WEBP, or SVG. Maximum file size: 8 MB.
                </p>
                <p
                  :for={error <- upload_errors(@uploads.certificate_layout_asset)}
                  class="mt-2 text-sm text-[var(--tracms-danger)]"
                >
                  {upload_error_message(error)}
                </p>
              </div>
            </div>

            <div class="mt-5 rounded-[var(--tracms-radius-md)] border border-dashed border-[var(--tracms-border)] bg-white/80 p-5">
              <%= case List.first(@uploads.certificate_layout_asset.entries) do %>
                <% nil -> %>
                  <%= if @certificate_layout_preview.asset_name do %>
                    <p class="font-medium text-[var(--tracms-text)]">
                      {@certificate_layout_preview.asset_name}
                    </p>
                    <a
                      href={@certificate_layout_preview.asset_path}
                      target="_blank"
                      rel="noopener"
                      class="mt-1 block break-all text-sm text-[var(--tracms-primary)] hover:underline"
                    >
                      View Current Background
                    </a>
                  <% else %>
                    <p class="text-sm text-[var(--tracms-text-muted)]">No Background Selected</p>
                  <% end %>
                <% entry -> %>
                  <div class="flex flex-wrap items-center justify-between gap-3">
                    <p class="font-medium text-[var(--tracms-text)]">{entry.client_name}</p>
                    <.button
                      type="button"
                      variant="ghost"
                      phx-click="cancel_certificate_layout_upload"
                      phx-value-ref={entry.ref}
                    >
                      Remove
                    </.button>
                  </div>
              <% end %>
            </div>

            <div class="mt-5 flex flex-wrap justify-end gap-3">
              <.button
                :if={@certificate_layout_preview.asset_name}
                type="button"
                variant="ghost"
                phx-click="remove_certificate_layout_asset"
              >
                Remove Current Background
              </.button>
              <.button phx-disable-with="Saving Certificate Layout...">
                Save Certificate Layout
              </.button>
            </div>
          </.form>
        </section>

        <%= if @trainings == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-calendar-days"
              title="No training activities yet"
              copy="Start by creating the first training activity for your office or division."
            >
              <:actions>
                <.link
                  navigate={~p"/trainings/new"}
                  class="portal-link-button portal-link-button-primary"
                >
                  Add training
                </.link>
              </:actions>
            </.portal_empty_state>
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header title="List of Trainings" />

            <div class="training-record-list">
              <article :for={training <- @trainings} class="training-record-card">
                <div class="training-record-head">
                  <div class="training-record-copy">
                    <div class="badge-row">
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{training_status_tone(training.status)}"
                      ]}>
                        {Trainings.format_status(training.status)}
                      </span>
                      <span class="badge-soft">{format_modality(training.modality)}</span>
                      <span class="badge-soft">{training.category}</span>
                    </div>

                    <h2 class="training-record-title">{training.title}</h2>

                    <p class="training-record-subtitle">
                      Led by {display_value(training.resource_speaker, "Facilitator to be assigned")}
                    </p>
                  </div>

                  <div class="training-record-actions">
                    <.button
                      :if={Trainings.editable?(training)}
                      navigate={~p"/trainings/#{training.id}/edit"}
                      variant="ghost"
                    >
                      Edit
                    </.button>
                  </div>
                </div>

                <div class="training-record-grid">
                  <div class="training-record-detail">
                    <span class="training-record-label">Schedule</span>
                    <span class="training-record-value">
                      {format_date(training.starts_on)} to {format_date(training.ends_on)}
                    </span>
                    <span class="training-record-meta">
                      {schedule_time_label(training.start_time, training.end_time)}
                    </span>
                  </div>

                  <div class="training-record-detail">
                    <span class="training-record-label">Venue</span>
                    <span class="training-record-value">{display_value(training.venue)}</span>
                    <span class="training-record-meta">
                      {display_value(training.venue_address, "Address to be announced")}
                    </span>
                  </div>

                  <div class="training-record-detail">
                    <span class="training-record-label">Registration deadline</span>
                    <span class="training-record-value">
                      {format_datetime(training.registration_deadline)}
                    </span>
                    <span class="training-record-meta">
                      {registration_deadline_copy(training.status)}
                    </span>
                  </div>

                  <div class="training-record-detail">
                    <span class="training-record-label">Maximum participants</span>
                    <span class="training-record-value">{training.max_capacity}</span>
                    <span class="training-record-meta">
                      {training.total_hours} training hour(s)
                    </span>
                  </div>
                </div>

                <div class="training-record-footer">
                  <div class="training-record-inline-actions">
                    <.button
                      navigate={~p"/trainings/#{training.id}"}
                      variant="secondary"
                    >
                      View
                    </.button>
                  </div>
                </div>
              </article>
            </div>
            <p class="mt-4 text-right text-sm text-slate-500">{@managed_training_caption}</p>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate_certificate_layout", params, socket) do
    params = Map.get(params, "certificate_layout_setting", %{})

    changeset =
      Certificates.change_default_certificate_layout(params)
      |> Map.put(:action, :validate)

    preview_source = Ecto.Changeset.apply_changes(changeset)

    {:noreply,
     socket
     |> assign(:certificate_layout_form, to_form(changeset))
     |> assign(
       :certificate_layout_preview,
       Certificates.default_certificate_layout(preview_source)
     )}
  end

  def handle_event("cancel_certificate_layout_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :certificate_layout_asset, ref)}
  end

  def handle_event("update_certificate_layout", params, socket) do
    params = Map.get(params, "certificate_layout_setting", %{})
    current_layout_setting = Certificates.get_default_certificate_layout_setting()
    {params, uploaded_asset_paths} = merge_uploaded_certificate_layout_asset(socket, params)

    case Certificates.update_default_certificate_layout(socket.assigns.current_scope, params) do
      {:ok, layout_setting} ->
        maybe_delete_replaced_asset(current_layout_setting.asset_path, layout_setting.asset_path)

        {:noreply,
         socket
         |> assign_saved_certificate_layout(layout_setting)
         |> put_flash(:info, "Certificate Layout Updated Successfully.")}

      {:error, :unauthorized} ->
        cleanup_uploaded_assets(uploaded_asset_paths)

        {:noreply,
         put_flash(socket, :error, "You Are Not Allowed to Update the Certificate Layout.")}

      {:error, changeset} ->
        cleanup_uploaded_assets(uploaded_asset_paths)
        preview_source = Ecto.Changeset.apply_changes(changeset)

        {:noreply,
         socket
         |> assign(:certificate_layout_form, to_form(changeset, action: :validate))
         |> assign(
           :certificate_layout_preview,
           Certificates.default_certificate_layout(preview_source)
         )}
    end
  end

  def handle_event("remove_certificate_layout_asset", _params, socket) do
    current_layout_setting = Certificates.get_default_certificate_layout_setting()

    case Certificates.update_default_certificate_layout(socket.assigns.current_scope, %{
           "asset_path" => "",
           "asset_name" => "",
           "asset_content_type" => ""
         }) do
      {:ok, _layout_setting} ->
        maybe_delete_asset(current_layout_setting.asset_path)

        {:noreply,
         socket
         |> assign_saved_certificate_layout(Certificates.get_default_certificate_layout_setting())
         |> put_flash(:info, "Certificate Background Removed Successfully.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You Are Not Allowed to Remove the Certificate Background.")}

      {:error, changeset} ->
        preview_source = Ecto.Changeset.apply_changes(changeset)

        {:noreply,
         socket
         |> assign(:certificate_layout_form, to_form(changeset, action: :validate))
         |> assign(
           :certificate_layout_preview,
           Certificates.default_certificate_layout(preview_source)
         )}
    end
  end

  defp load_trainings(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)

    socket
    |> assign(:trainings, trainings)
    |> assign(:managed_training_caption, managed_training_caption(trainings))
  end

  defp managed_training_caption(trainings) do
    count = length(trainings)

    "#{count} training #{if(count == 1, do: "record", else: "records")} with direct management links."
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

  defp registration_deadline_copy(status) do
    case status do
      :published -> "Registration is currently open."
      :registration_closed -> "Registration is closed."
      :in_progress -> "Training already started."
      :completed -> "Training already completed."
      :cancelled -> "Training was cancelled."
      :archived -> "Record already archived."
      _ -> "Review this date before publishing the activity."
    end
  end

  defp assign_saved_certificate_layout(socket, layout_setting) do
    socket
    |> assign(:certificate_layout_form, to_form(Certificates.change_default_certificate_layout()))
    |> assign(
      :certificate_layout_preview,
      Certificates.default_certificate_layout(layout_setting)
    )
  end

  defp merge_uploaded_certificate_layout_asset(socket, params) do
    uploaded_assets =
      consume_uploaded_entries(socket, :certificate_layout_asset, fn %{path: path}, entry ->
        public_path = build_certificate_asset_public_path(entry.client_name)
        file_path = certificate_asset_storage_path(public_path)
        File.mkdir_p!(Path.dirname(file_path))
        File.cp!(path, file_path)

        {:ok,
         %{
           "asset_path" => public_path,
           "asset_name" => entry.client_name,
           "asset_content_type" =>
             certificate_layout_asset_content_type(entry.client_name, entry.client_type),
           "__stored_path__" => file_path
         }}
      end)

    case uploaded_assets do
      [] ->
        {params, []}

      [asset_attrs] ->
        stored_path = Map.fetch!(asset_attrs, "__stored_path__")
        {Map.merge(params, Map.drop(asset_attrs, ["__stored_path__"])), [stored_path]}
    end
  end

  defp cleanup_uploaded_assets(paths), do: Enum.each(paths, &File.rm/1)

  defp maybe_delete_replaced_asset(nil, _new_path), do: :ok
  defp maybe_delete_replaced_asset(old_path, old_path), do: :ok
  defp maybe_delete_replaced_asset(old_path, _new_path), do: maybe_delete_asset(old_path)
  defp maybe_delete_asset(nil), do: :ok

  defp maybe_delete_asset(asset_path) do
    asset_path
    |> certificate_asset_storage_path()
    |> File.rm()
  end

  defp build_certificate_asset_public_path(client_name) do
    extension = Path.extname(client_name)
    unique_name = "#{System.system_time(:millisecond)}-#{Ecto.UUID.generate()}#{extension}"
    "/uploads/certificate-layouts/#{unique_name}"
  end

  defp certificate_layout_asset_content_type(client_name, client_type) do
    case client_type do
      value when is_binary(value) and value != "" -> value
      _value -> MIME.from_path(client_name)
    end || MIME.from_path(client_name)
  end

  defp certificate_asset_storage_path(public_path) do
    Application.app_dir(:tracms, "priv/static" <> public_path)
  end

  defp upload_error_message(:too_large), do: "File Is Too Large."
  defp upload_error_message(:not_accepted), do: "File Type Is Not Supported."
  defp upload_error_message(:too_many_files), do: "Only One File Can Be Uploaded."
  defp upload_error_message(_error), do: "Upload Failed."

  defp display_value(value, fallback \\ "Not set")

  defp display_value(nil, fallback), do: fallback

  defp display_value(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      normalized_value -> normalized_value
    end
  end

  defp display_value(value, _fallback), do: value
end
