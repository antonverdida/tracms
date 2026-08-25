defmodule TracmsWeb.TrainingLive.Form do
  use TracmsWeb, :live_view

  alias Tracms.Accounts.Scope
  alias Tracms.Certificates
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @certificate_asset_accept ~w(.png .jpg .jpeg .webp .svg .pdf application/pdf)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_saved_certificate_layout(Certificates.get_default_certificate_layout_setting())
     |> assign(:certificate_layout_saved?, false)
     |> assign(:created_training, nil)
     |> allow_upload(:certificate_layout_asset,
       accept: @certificate_asset_accept,
       max_entries: 1,
       max_file_size: 8_000_000,
       auto_upload: true,
       progress: &handle_certificate_layout_upload_progress/3
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
     |> assign(:certificate_layout_saved?, false)
     |> assign(
       :certificate_layout_preview,
       Certificates.default_certificate_layout(preview_source)
     )}
  end

  def handle_event("cancel_certificate_layout_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :certificate_layout_asset, ref)}
  end

  def handle_event(
        "detect_participant_name_line",
        %{"asset_path" => asset_path, "position" => position},
        socket
      ) do
    layout_setting = Certificates.get_default_certificate_layout_setting()

    if layout_setting.asset_path == asset_path do
      save_participant_name_position(socket, position, "detected")
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_certificate_layout", params, socket) do
    params = Map.get(params, "certificate_layout_setting", %{})
    current_layout_setting = Certificates.get_default_certificate_layout_setting()

    {params, upload_error} =
      merge_uploaded_certificate_layout_asset(socket, params)

    case upload_error do
      nil ->
        update_certificate_layout(socket, params, current_layout_setting)

      error ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  def handle_event("remove_certificate_layout_asset", _params, socket) do
    case Certificates.update_default_certificate_layout(socket.assigns.current_scope, %{
           "asset_path" => "",
           "asset_name" => "",
           "asset_content_type" => "",
           "asset_data" => nil,
           "asset_size" => nil
         }) do
      {:ok, _layout_setting} ->
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

  defp update_certificate_layout(socket, params, _current_layout_setting) do
    case Certificates.update_default_certificate_layout(socket.assigns.current_scope, params) do
      {:ok, layout_setting} ->
        {:noreply,
         socket
         |> assign_saved_certificate_layout(layout_setting)
         |> assign(:certificate_layout_saved?, true)
         |> put_flash(:info, "Certificate Layout Updated Successfully.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to update the certificate layout.")}

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

  defp handle_certificate_layout_upload_progress(:certificate_layout_asset, entry, socket) do
    if entry.done? do
      current_layout_setting = Certificates.get_default_certificate_layout_setting()

      {asset_params, upload_error} =
        merge_uploaded_certificate_layout_asset(socket, %{})

      case upload_error do
        nil ->
          save_uploaded_certificate_layout(socket, asset_params, current_layout_setting)

        error ->
          {:noreply, put_flash(socket, :error, error)}
      end
    else
      {:noreply, assign(socket, :certificate_layout_saved?, false)}
    end
  end

  defp save_uploaded_certificate_layout(socket, asset_params, _current_layout_setting) do
    case Certificates.update_default_certificate_layout(
           socket.assigns.current_scope,
           asset_params
         ) do
      {:ok, layout_setting} ->
        {:noreply,
         socket
         |> assign_saved_certificate_layout(layout_setting)
         |> assign(:certificate_layout_saved?, true)
         |> put_flash(:info, "Certificate layout saved automatically.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to update the certificate layout.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to save the certificate layout.")}
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
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to List of Trainings</.button>
            <.button
              :if={is_nil(@created_training)}
              id="save-training-button"
              form="training-form"
              type="submit"
              phx-disable-with="Saving Training..."
            >
              {if @live_action == :new, do: "Create Training", else: "Save Changes"}
            </.button>
          </:actions>
        </.portal_page_header>

        <section
          :if={@created_training}
          id="training-created-confirmation"
          class="panel portal-list-panel border-emerald-200 bg-emerald-50/70"
        >
          <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
            <div class="flex items-start gap-3">
              <.icon name="hero-check-circle" class="mt-0.5 size-7 shrink-0 text-emerald-700" />
              <div>
                <p class="text-lg font-bold text-emerald-950">Training created successfully</p>
                <p class="mt-1 text-sm text-emerald-900">
                  {@created_training.title} is now available in the training list.
                </p>
              </div>
            </div>
            <div class="flex flex-wrap gap-3">
              <.button navigate={~p"/trainings/#{@created_training.id}"} variant="secondary">
                View Training
              </.button>
              <.button navigate={~p"/trainings"}>Back to List of Trainings</.button>
            </div>
          </div>
        </section>

        <.form
          :if={is_nil(@created_training)}
          for={@form}
          id="training-form"
          phx-change="validate"
          phx-submit="save"
        >
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
                eyebrow="Delivery context"
                title="Training venue"
                meta="Set where and how the training will be delivered."
              />

              <div class="grid gap-5 md:grid-cols-2">
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
                </div>
              </div>
            </section>
          </div>
        </.form>

        <section
          :if={
            @live_action == :new and is_nil(@created_training) and Scope.system_admin?(@current_scope)
          }
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
            <div class="grid gap-5">
              <div class="max-w-2xl">
                <.input
                  field={@certificate_layout_form[:certificate_size]}
                  type="select"
                  label="Certificate Size"
                  options={Certificates.certificate_size_options()}
                />
              </div>
              <div>
                <label class="block text-sm font-semibold text-[var(--tracms-text)]">
                  Certificate Background
                  <span class="ml-1 text-[var(--tracms-danger)]">
                    Required before creating a training
                  </span>
                </label>
                <div
                  id="certificate-layout-dropzone"
                  class="certificate-layout-dropzone mt-2"
                  phx-drop-target={@uploads.certificate_layout_asset.ref}
                >
                  <span class="certificate-layout-dropzone-icon">
                    <.icon name="hero-arrow-up-tray" class="size-6" />
                  </span>
                  <div class="certificate-layout-dropzone-copy">
                    <p>Drag and drop your certificate layout here</p>
                    <p>PNG, JPG, WEBP, SVG, or a one-page PDF up to 8 MB.</p>
                  </div>
                  <.live_file_input
                    id="certificate-layout-upload"
                    upload={@uploads.certificate_layout_asset}
                    class="certificate-layout-upload-input"
                    aria-describedby="certificate-layout-upload-help"
                  />
                </div>
                <p id="certificate-layout-upload-help" class="sr-only">
                  Drag and drop a certificate background or choose a file from your device.
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
                    <div class="grid gap-4 sm:grid-cols-[13rem_1fr] sm:items-center">
                      <div class="certificate-layout-calibration-preview">
                        <img
                          id="certificate-layout-detection-image"
                          src={certificate_layout_preview_url(@certificate_layout_preview)}
                          alt="Current Certificate Background Preview"
                          class="certificate-layout-calibration-image"
                          data-asset-path={@certificate_layout_preview.asset_path}
                          phx-hook="CertificateLayoutLineDetection"
                        />
                        <span
                          class="certificate-layout-calibration-name"
                          style={
                            "top: #{@certificate_layout_preview.participant_name_position || 39.0}%"
                          }
                        >
                          Sample Participant Name
                        </span>
                      </div>
                      <div>
                        <p class="font-medium text-[var(--tracms-text)]">
                          {@certificate_layout_preview.asset_name}
                        </p>
                        <p class="mt-1 text-sm text-emerald-700">
                          Saved layout currently in use.
                        </p>
                        <a
                          href={certificate_layout_preview_url(@certificate_layout_preview)}
                          target="_blank"
                          rel="noopener"
                          class="mt-1 inline-flex text-sm font-semibold text-[var(--tracms-primary)] hover:underline"
                        >
                          View Full-Size Background
                        </a>
                        <div class="certificate-layout-calibration-control">
                          <p class="font-semibold text-[var(--tracms-text)]">
                            Automatic participant-name placement
                          </p>
                          <p class="text-sm text-[var(--tracms-text-muted)]">
                            {participant_name_position_source_label(
                              @certificate_layout_preview.participant_name_position_source
                            )}
                          </p>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <p class="text-sm text-[var(--tracms-text-muted)]">No Background Selected</p>
                  <% end %>
                <% entry -> %>
                  <div class="grid gap-4 sm:grid-cols-[13rem_1fr] sm:items-center">
                    <%= if certificate_layout_pdf?(entry) do %>
                      <div class="flex aspect-[1.414/1] w-full flex-col items-center justify-center gap-2 rounded-[var(--tracms-radius-sm)] border border-[var(--tracms-border)] bg-slate-100 text-slate-600">
                        <.icon name="hero-document-text" class="size-10 text-[var(--tracms-primary)]" />
                        <span class="text-sm font-semibold">PDF layout</span>
                      </div>
                    <% else %>
                      <.live_img_preview
                        entry={entry}
                        class="aspect-[1.414/1] w-full rounded-[var(--tracms-radius-sm)] border border-[var(--tracms-border)] bg-slate-100 object-cover"
                      />
                    <% end %>
                    <div class="flex flex-wrap items-center justify-between gap-3">
                      <div>
                        <p class="font-medium text-[var(--tracms-text)]">{entry.client_name}</p>
                        <p class="mt-1 text-sm text-amber-700">
                          Saving layout automatically. PDF layouts are converted to PNG before saving.
                        </p>
                      </div>
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

            <div
              :if={@certificate_layout_saved?}
              id="certificate-layout-save-confirmation"
              class="mt-5 flex items-start gap-3 rounded-[var(--tracms-radius-md)] border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900"
            >
              <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-emerald-700" />
              <p>
                Layout saved. New certificates will use this background and document-control details.
              </p>
            </div>

            <div class="mt-5 flex flex-wrap justify-end">
              <.button
                :if={@certificate_layout_preview.asset_name}
                type="button"
                variant="ghost"
                phx-click="remove_certificate_layout_asset"
              >
                Remove Certificate
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp save_training_activity(socket, :new, training_params) do
    if certificate_layout_required?(socket) do
      {:noreply,
       put_flash(
         socket,
         :error,
         certificate_layout_requirement_message(socket)
       )}
    else
      create_training_activity(socket, training_params)
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

  defp create_training_activity(socket, training_params) do
    case Trainings.create_training_activity(socket.assigns.current_scope, training_params) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> assign(:created_training, training_activity)
         |> put_flash(:info, "Training activity created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You do not have permission to create training activities.")
         |> push_navigate(to: ~p"/trainings")}
    end
  end

  defp certificate_layout_required?(socket),
    do:
      Scope.system_admin?(socket.assigns.current_scope) and
        not socket.assigns.certificate_layout_ready?

  defp certificate_layout_requirement_message(socket) do
    case socket.assigns.uploads.certificate_layout_asset.entries do
      [] ->
        "Upload a certificate layout before creating a training."

      _entries ->
        "The certificate layout is still uploading. Wait for the green saved confirmation."
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp assign_saved_certificate_layout(socket, layout_setting) do
    socket
    |> assign(:certificate_layout_form, to_form(Certificates.change_default_certificate_layout()))
    |> assign(:certificate_layout_ready?, certificate_layout_ready?(layout_setting))
    |> assign(
      :certificate_layout_preview,
      Certificates.default_certificate_layout(layout_setting)
    )
  end

  defp certificate_layout_ready?(%{asset_path: asset_path}) when is_binary(asset_path),
    do: String.trim(asset_path) != ""

  defp certificate_layout_ready?(%{asset_data: asset_data}) when is_binary(asset_data),
    do: byte_size(asset_data) > 0

  defp certificate_layout_ready?(_layout_setting), do: false

  defp save_participant_name_position(socket, position, source) do
    case Float.parse(to_string(position)) do
      {value, ""} when value >= 15 and value <= 75 ->
        case Certificates.update_default_certificate_layout(socket.assigns.current_scope, %{
               "participant_name_position" => value,
               "participant_name_position_source" => source
             }) do
          {:ok, updated_layout_setting} ->
            {:noreply, assign_saved_certificate_layout(socket, updated_layout_setting)}

          {:error, _reason} ->
            {:noreply, socket}
        end

      _invalid ->
        {:noreply, socket}
    end
  end

  defp participant_name_position_source_label("detected"),
    do: "Suggested automatically from the strongest blank name line in this layout."

  defp participant_name_position_source_label(_source),
    do:
      "No suitable blank name line was found, so the standard certificate position is being used."

  defp merge_uploaded_certificate_layout_asset(socket, params) do
    uploaded_assets =
      consume_uploaded_entries(socket, :certificate_layout_asset, fn %{path: path}, entry ->
        {:ok, store_certificate_layout_asset(path, entry)}
      end)

    case uploaded_assets do
      [] ->
        {params, nil}

      [{:ok, asset_attrs}] ->
        {Map.merge(params, asset_attrs), nil}

      [{:error, reason}] ->
        {params, reason}
    end
  end

  defp store_certificate_layout_asset(path, entry) do
    if certificate_layout_pdf?(entry) do
      convert_certificate_pdf_to_image(path, entry.client_name)
    else
      copy_certificate_layout_image(path, entry)
    end
  end

  defp copy_certificate_layout_image(path, entry) do
    with {:ok, asset_data} <- File.read(path) do
      {:ok,
       %{
         "asset_path" => "database://default",
         "asset_name" => entry.client_name,
         "asset_content_type" =>
           certificate_layout_asset_content_type(entry.client_name, entry.client_type),
         "asset_data" => asset_data,
         "asset_size" => byte_size(asset_data)
       }}
    end
  rescue
    error -> {:error, "Unable to save the certificate layout: #{Exception.message(error)}"}
  end

  defp convert_certificate_pdf_to_image(path, client_name) do
    file_path = Path.join(System.tmp_dir!(), "tracms-layout-#{Ecto.UUID.generate()}.png")

    try do
      with :ok <- render_certificate_pdf(path, file_path),
           {:ok, asset_data} <- File.read(file_path) do
        {:ok,
         %{
           "asset_path" => "database://default",
           "asset_name" => client_name,
           "asset_content_type" => "image/png",
           "asset_data" => asset_data,
           "asset_size" => byte_size(asset_data)
         }}
      else
        _error ->
          {:error, "The PDF could not be converted. Use a one-page PDF or an image layout."}
      end
    rescue
      _error -> {:error, "The PDF could not be converted. Use a one-page PDF or an image layout."}
    after
      File.rm(file_path)
    end
  end

  defp render_certificate_pdf(source_path, target_path) do
    case System.find_executable("pdftoppm") do
      executable when is_binary(executable) ->
        case System.cmd(
               executable,
               [
                 "-f",
                 "1",
                 "-l",
                 "1",
                 "-png",
                 "-singlefile",
                 "-r",
                 "144",
                 source_path,
                 Path.rootname(target_path)
               ],
               stderr_to_stdout: true
             ) do
          {_output, 0} -> :ok
          {_output, _status} -> {:error, :conversion_failed}
        end

      nil ->
        render_certificate_pdf_with_sips(source_path, target_path)
    end
  end

  # macOS development machines include sips, while Docker uses Poppler's pdftoppm.
  defp render_certificate_pdf_with_sips(source_path, target_path) do
    with executable when is_binary(executable) <- System.find_executable("sips"),
         {_output, 0} <-
           System.cmd(executable, ["-s", "format", "png", source_path, "--out", target_path],
             stderr_to_stdout: true
           ) do
      :ok
    else
      _ -> {:error, :conversion_failed}
    end
  end

  defp certificate_layout_pdf?(entry) do
    entry.client_type == "application/pdf" or
      String.downcase(Path.extname(entry.client_name)) == ".pdf"
  end

  defp certificate_layout_asset_content_type(client_name, client_type) do
    case client_type do
      value when is_binary(value) and value != "" -> value
      _value -> MIME.from_path(client_name)
    end || MIME.from_path(client_name)
  end

  defp certificate_layout_preview_url(%{asset_data: asset_data, asset_content_type: content_type})
       when is_binary(asset_data) and byte_size(asset_data) > 0 and is_binary(content_type),
       do: "data:#{content_type};base64," <> Base.encode64(asset_data)

  defp certificate_layout_preview_url(%{asset_path: asset_path}), do: asset_path

  defp upload_error_message(:too_large), do: "File Is Too Large."
  defp upload_error_message(:not_accepted), do: "Use a PNG, JPG, WEBP, SVG, or one-page PDF file."
  defp upload_error_message(:too_many_files), do: "Only One File Can Be Uploaded."
  defp upload_error_message(_error), do: "Upload Failed."
end
