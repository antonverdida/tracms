defmodule TracmsWeb.TrainingLive.Form do
  use TracmsWeb, :live_view

  alias Tracms.Accounts.Scope
  alias Tracms.Certificates
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @certificate_asset_accept ~w(.png .jpg .jpeg .webp .svg)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_saved_certificate_layout(Certificates.get_default_certificate_layout_setting())
     |> allow_upload(:certificate_layout_asset,
       accept: @certificate_asset_accept,
       max_entries: 1,
       max_file_size: 8_000_000
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new ->
          training_activity = %TrainingActivity{}

          socket
          |> assign(:page_title, "Add Training")
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
         put_flash(socket, :error, "You are not allowed to update the certificate layout.")}

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
         put_flash(socket, :error, "You are not allowed to remove the certificate background.")}

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
          copy="Use one guided form to prepare the training record, registration setup, delivery details, and completion rules before opening the workspace."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to Trainings</.button>
          </:actions>
        </.portal_page_header>

        <.form for={@form} id="training-form" phx-change="validate" phx-submit="save">
          <div class="portal-panel-stack">
            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Basic information"
                title="Training profile"
                meta="Record the official title, type, organizer, and lead facilitator."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <div class="md:col-span-2">
                  <.input field={@form[:title]} type="text" label="Training Title" />
                </div>
                <.input
                  field={@form[:category]}
                  type="text"
                  label="Training Category"
                  placeholder="e.g. Teacher Development"
                  list="training-category-options"
                />
                <.input
                  field={@form[:training_type]}
                  type="text"
                  label="Training Type"
                  placeholder="e.g. Capacity Building Training"
                  list="training-type-options"
                />
                <datalist id="training-category-options">
                  <option :for={{label, _value} <- TrainingActivity.category_options()} value={label} />
                </datalist>
                <datalist id="training-type-options">
                  <option
                    :for={{label, _value} <- TrainingActivity.training_type_options()}
                    value={label}
                  />
                </datalist>
                <.input field={@form[:organizer]} type="text" label="Implementing Office" />
                <.input
                  field={@form[:resource_speaker]}
                  type="text"
                  label="Resource Speaker or Facilitator"
                  placeholder="Name of the speaker, facilitator, or lead trainer"
                />
              </div>
            </section>

            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Schedule and registration"
                title="Training schedule"
                meta="All fields are optional. Add dates, time windows, capacity, and registration cutoffs when available."
              />

              <div class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
                <.input field={@form[:starts_on]} type="date" label="Training Date Start" />
                <.input field={@form[:ends_on]} type="date" label="Training Date End" />
                <.input
                  field={@form[:total_hours]}
                  type="number"
                  label="Total Training Hours"
                  min="1"
                />
                <.input field={@form[:start_time]} type="time" label="Start Time" />
                <.input field={@form[:end_time]} type="time" label="End Time" />
                <.input
                  field={@form[:max_capacity]}
                  type="number"
                  label="Maximum Participants"
                  min="1"
                />
                <.input
                  field={@form[:registration_opens_on]}
                  type="date"
                  label="Registration Opening Date"
                />
                <div class="md:col-span-2 xl:col-span-2">
                  <.input
                    field={@form[:registration_deadline]}
                    type="datetime-local"
                    label="Registration Deadline"
                  />
                </div>
              </div>
            </section>

            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Training narrative and delivery"
                title="Description and delivery context"
                meta="Describe the training, where it will happen, and who should attend."
              />

              <div class="grid gap-8">
                <div class="grid gap-5">
                  <div>
                    <p class="feature-title">Training Description</p>
                    <p class="feature-copy">
                      Keep the official description and objectives on the same record used by the rest of the workspace.
                    </p>
                  </div>
                  <.input
                    field={@form[:description]}
                    type="textarea"
                    label="Description"
                    rows="4"
                  />
                  <.input
                    field={@form[:objectives]}
                    type="textarea"
                    label="Objectives"
                    rows="4"
                  />
                </div>

                <div class="grid gap-5 border-t border-slate-200 pt-8 md:grid-cols-2">
                  <div class="md:col-span-2">
                    <p class="feature-title">Delivery Context</p>
                    <p class="feature-copy">
                      Describe where the training will happen and who should attend.
                    </p>
                  </div>
                  <.input
                    field={@form[:modality]}
                    type="select"
                    label="Training Modality"
                    options={TrainingActivity.modality_options()}
                  />
                  <.input field={@form[:venue]} type="text" label="Venue" />
                  <div class="md:col-span-2">
                    <.input field={@form[:venue_address]} type="text" label="Venue Address" />
                  </div>
                  <div class="md:col-span-2">
                    <.input
                      field={@form[:target_participants]}
                      type="textarea"
                      label="Target Participants"
                      rows="4"
                    />
                  </div>
                  <div class="md:col-span-2">
                    <.input
                      field={@form[:participant_qualification]}
                      type="textarea"
                      label="Participant Qualification"
                      rows="4"
                    />
                  </div>
                </div>
              </div>
            </section>

            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Completion rules"
                title="Attendance and certificates"
                meta="Define the rules the training workspace will use for attendance and completion."
              />

              <div class="grid gap-5 md:grid-cols-2">
                <.input
                  field={@form[:attendance_monitoring_method]}
                  type="select"
                  label="Attendance Monitoring Method"
                  options={TrainingActivity.attendance_monitoring_method_options()}
                />
                <.input
                  field={@form[:certificate_type]}
                  type="select"
                  label="Certificate Type"
                  options={TrainingActivity.certificate_type_options()}
                />
                <.input
                  field={@form[:minimum_attendance_percentage]}
                  type="number"
                  label="Minimum Attendance Percentage"
                  min="0"
                  max="100"
                />
                <.input
                  field={@form[:evaluation_required]}
                  type="checkbox"
                  label="Require Participant Evaluation Before Completion"
                />
              </div>
            </section>

            <section class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Registration and integrations"
                title="Registration workflow"
                meta="Add external registration forms and response sheets only when needed."
              />

              <div class="portal-panel-stack">
                <div class="grid gap-5 md:grid-cols-2">
                  <div class="md:col-span-2">
                    <.input
                      field={@form[:registration_form_url]}
                      type="url"
                      label="Registration Form URL"
                      placeholder="Optional external form link"
                    />
                  </div>
                  <.input
                    field={@form[:registration_sheet_id]}
                    type="text"
                    label="Registration Sheet ID"
                    placeholder="Optional Google Sheet ID"
                  />
                  <.input
                    field={@form[:registration_sheet_range]}
                    type="text"
                    label="Registration Sheet Range"
                    placeholder="Form Responses 1!A:F"
                  />
                  <div class="md:col-span-2">
                    <.input
                      field={@form[:attendance_form_url]}
                      type="url"
                      label="Attendance Form URL"
                      placeholder="Optional external attendance form link"
                    />
                  </div>
                  <.input
                    field={@form[:attendance_sheet_id]}
                    type="text"
                    label="Attendance Sheet ID"
                    placeholder="Optional Google Sheet ID"
                  />
                  <.input
                    field={@form[:attendance_sheet_range]}
                    type="text"
                    label="Attendance Sheet Range"
                    placeholder="Attendance!A:C"
                  />
                </div>
              </div>
            </section>
          </div>

          <div class="mt-6 flex flex-wrap justify-end gap-3">
            <.button navigate={~p"/trainings"} variant="ghost">Cancel</.button>
            <.button phx-disable-with="Saving Training...">
              {if @live_action == :new, do: "Create Training", else: "Save Changes"}
            </.button>
          </div>
        </.form>

        <section
          :if={@live_action == :new and Scope.system_admin?(@current_scope)}
          class="mt-8 panel portal-list-panel"
        >
          <.portal_panel_header
            eyebrow="Certificates"
            title="Certificate Layout"
            meta="Set the default certificate size and background for new training records."
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
              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@certificate_layout_form[:certificate_number_start]}
                  type="number"
                  min="1"
                  max="999999"
                  label="Certificate Number Starts From"
                />
                <.input
                  field={@certificate_layout_form[:certificate_number_end]}
                  type="number"
                  min="1"
                  max="999999"
                  label="Certificate Number Ends At"
                />
              </div>
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

            <p class="text-sm text-[var(--tracms-text-muted)]">
              Certificate numbers use the format DEPED9-YYYY-###### and are issued sequentially within this range.
            </p>

            <div class="mt-5 rounded-[var(--tracms-radius-md)] border border-dashed border-[var(--tracms-border)] bg-white/80 p-5">
              <%= case List.first(@uploads.certificate_layout_asset.entries) do %>
                <% nil -> %>
                  <%= if @certificate_layout_preview.asset_name do %>
                    <div class="grid gap-4 sm:grid-cols-[13rem_1fr] sm:items-center">
                      <a
                        href={@certificate_layout_preview.asset_path}
                        target="_blank"
                        rel="noopener"
                        class="overflow-hidden rounded-[var(--tracms-radius-sm)] border border-[var(--tracms-border)] bg-slate-100"
                      >
                        <img
                          src={@certificate_layout_preview.asset_path}
                          alt="Current Certificate Background Preview"
                          class="aspect-[1.414/1] h-full w-full object-cover"
                        />
                      </a>
                      <div>
                        <p class="font-medium text-[var(--tracms-text)]">
                          {@certificate_layout_preview.asset_name}
                        </p>
                        <a
                          href={@certificate_layout_preview.asset_path}
                          target="_blank"
                          rel="noopener"
                          class="mt-1 inline-flex text-sm font-semibold text-[var(--tracms-primary)] hover:underline"
                        >
                          View Full-Size Background
                        </a>
                      </div>
                    </div>
                  <% else %>
                    <p class="text-sm text-[var(--tracms-text-muted)]">No Background Selected</p>
                  <% end %>
                <% entry -> %>
                  <div class="grid gap-4 sm:grid-cols-[13rem_1fr] sm:items-center">
                    <.live_img_preview
                      entry={entry}
                      class="aspect-[1.414/1] w-full rounded-[var(--tracms-radius-sm)] border border-[var(--tracms-border)] bg-slate-100 object-cover"
                    />
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
                Remove Certificate
              </.button>
              <.button phx-disable-with="Saving Certificate Layout...">
                Save Certificate Layout
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
      {:ok, _training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity created successfully.")
         |> push_navigate(to: ~p"/trainings")}

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
      {:ok, _training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Training activity updated successfully.")
         |> push_navigate(to: ~p"/trainings")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "This training activity can no longer be edited.")
         |> push_navigate(to: ~p"/trainings")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
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
end
