defmodule TracmsWeb.UserLive.Settings do
  use TracmsWeb, :live_view

  alias Tracms.Accounts
  alias Tracms.Accounts.Scope
  alias Tracms.Certificates

  @certificate_asset_accept ~w(.png .jpg .jpeg .webp .svg)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="settings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Settings"
          title="Account Settings"
          copy="Manage your profile, access, and security settings."
        >
          <:actions>
            <.button navigate={~p"/dashboard"} variant="ghost">Back to Dashboard</.button>
          </:actions>
        </.portal_page_header>

        <div class="content-grid">
          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header
              eyebrow="Profile"
              title="Profile Information"
            />

            <.form
              for={@profile_form}
              id="profile_form"
              phx-submit="update_profile"
              phx-change="validate_profile"
            >
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={@profile_form[:full_name]}
                  type="text"
                  label="Full Name"
                  autocomplete="name"
                  placeholder="Juan Dela Cruz"
                />
                <.input
                  field={@profile_form[:employee_number]}
                  type="text"
                  label="Employee ID"
                  placeholder="DEPED-2026-00125"
                />
              </div>

              <div class="mt-6 grid gap-3 md:grid-cols-3">
                <div class="feature-card">
                  <div class="feature-title">Office</div>
                  <div class="feature-copy">{office_name(@current_scope.user)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Division</div>
                  <div class="feature-copy">{division_name(@current_scope.user)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Current Email</div>
                  <div class="feature-copy">{@current_email}</div>
                </div>
              </div>

              <div class="mt-6 flex justify-end">
                <.button variant="primary" phx-disable-with="Saving...">Save Profile</.button>
              </div>
            </.form>

            <div class="mt-8 border-t border-[var(--tracms-border)] pt-8">
              <div class="mb-5">
                <p class="eyebrow">Security</p>
                <h3 class="section-title">Email And Password</h3>
              </div>

              <div class="grid gap-4 lg:grid-cols-2">
                <div class="rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white/70 p-5">
                  <h4 class="text-base font-semibold text-[var(--tracms-text)]">Change email</h4>

                  <.form
                    for={@email_form}
                    id="email_form"
                    phx-submit="update_email"
                    phx-change="validate_email"
                    class="mt-5"
                  >
                    <.input
                      field={@email_form[:email]}
                      type="email"
                      label="New Email Address"
                      autocomplete="username"
                      spellcheck="false"
                      required
                    />
                    <div class="mt-4 flex justify-end">
                      <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
                    </div>
                  </.form>
                </div>

                <div class="rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white/70 p-5">
                  <h4 class="text-base font-semibold text-[var(--tracms-text)]">Update password</h4>

                  <.form
                    for={@password_form}
                    id="password_form"
                    action={~p"/users/update-password"}
                    method="post"
                    phx-change="validate_password"
                    phx-submit="update_password"
                    phx-trigger-action={@trigger_submit}
                    class="mt-5"
                  >
                    <input
                      name={@password_form[:username].name}
                      type="hidden"
                      id="hidden_user_username"
                      spellcheck="false"
                      value={@current_scope.user.username}
                    />
                    <div class="grid gap-4">
                      <.input
                        field={@password_form[:password]}
                        type="password"
                        label="New Password"
                        autocomplete="new-password"
                        spellcheck="false"
                        required
                      />
                      <.input
                        field={@password_form[:password_confirmation]}
                        type="password"
                        label="Confirm New Password"
                        autocomplete="new-password"
                        spellcheck="false"
                      />
                    </div>
                    <div class="mt-4 flex justify-end">
                      <.button variant="primary" phx-disable-with="Saving...">
                        Update Password
                      </.button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          </section>

          <section
            :if={false}
            class="hidden"
            aria-hidden="true"
          >
            <.portal_panel_header
              eyebrow="Certificates"
              title="Certificate Layout"
            />

            <div class="portal-form-section">
              <.form
                for={@certificate_layout_form}
                id="certificate_layout_form"
                phx-submit="update_certificate_layout"
                phx-change="validate_certificate_layout"
              >
                <div class="rounded-[var(--tracms-radius-md)] border border-dashed border-[var(--tracms-border)] bg-white/80 p-5">
                  <div>
                    <.input
                      field={@certificate_layout_form[:certificate_size]}
                      type="select"
                      label="Certificate Size"
                      options={Certificates.certificate_size_options()}
                    />
                  </div>

                  <div class="mt-4">
                    <label class="block text-sm font-semibold text-[var(--tracms-text)]">
                      Choose photo
                    </label>
                    <.live_file_input
                      upload={@uploads.certificate_layout_asset}
                      class="mt-2 block w-full text-sm text-[var(--tracms-text-muted)] file:mr-4 file:cursor-pointer file:rounded-full file:border-0 file:bg-[var(--tracms-primary)] file:px-5 file:py-2.5 file:text-sm file:font-semibold file:text-white file:shadow-[0_14px_30px_rgba(0,51,102,0.16)] hover:file:bg-[var(--tracms-primary-strong)]"
                    />

                    <div class="certificate-layout-upload-state mt-3">
                      <%= case List.first(@uploads.certificate_layout_asset.entries) do %>
                        <% nil -> %>
                          <%= if @certificate_layout_preview.asset_name do %>
                            <p class="certificate-layout-upload-name">
                              {@certificate_layout_preview.asset_name}
                            </p>
                            <a
                              href={@certificate_layout_preview.asset_path}
                              target="_blank"
                              rel="noopener"
                              class="certificate-layout-upload-link"
                            >
                              {@certificate_layout_preview.asset_path}
                            </a>
                          <% else %>
                            <p class="certificate-layout-upload-placeholder">
                              No photo selected.
                            </p>
                          <% end %>
                        <% entry -> %>
                          <p class="certificate-layout-upload-name">{entry.client_name}</p>
                          <p class="certificate-layout-upload-pending">
                            Ready to save this selected photo.
                          </p>
                      <% end %>
                    </div>

                    <p class="mt-2 text-sm text-[var(--tracms-text-muted)]">
                      Accepted: PNG, JPG, WEBP, SVG
                    </p>

                    <p
                      :for={error <- upload_errors(@uploads.certificate_layout_asset)}
                      class="mt-2 text-sm text-[var(--tracms-danger)]"
                    >
                      {upload_error_message(error)}
                    </p>

                    <div
                      :for={entry <- @uploads.certificate_layout_asset.entries}
                      class="mt-3 flex items-center justify-between gap-3 rounded-[var(--tracms-radius-sm)] border border-[var(--tracms-border)] bg-[var(--tracms-surface)] px-4 py-3"
                    >
                      <div>
                        <p class="font-medium text-[var(--tracms-text)]">{entry.client_name}</p>
                        <p class="text-sm text-[var(--tracms-text-muted)]">
                          Pending upload
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

                    <div
                      :if={@certificate_layout_preview.asset_name}
                      class="mt-4 flex items-center justify-end"
                    >
                      <.button
                        type="button"
                        variant="ghost"
                        phx-click="remove_certificate_layout_asset"
                      >
                        Remove Current Photo
                      </.button>
                    </div>
                  </div>
                </div>

                <div class="mt-4 flex justify-end">
                  <.button variant="primary" phx-disable-with="Saving...">Save</.button>
                </div>
              </.form>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> load_user_settings(user)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> allow_upload(:certificate_layout_asset,
        accept: @certificate_asset_accept,
        max_entries: 1,
        max_file_size: 8_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    profile_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile(profile_attrs(user_params))
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, profile_form: profile_form)}
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

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_profile(user, profile_attrs(user_params)) do
      {:ok, updated_user} ->
        updated_user =
          %{updated_user | authenticated_at: socket.assigns.current_scope.user.authenticated_at}

        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> load_user_settings(updated_user)
         |> put_flash(:info, "Profile updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset, action: :insert))}
    end
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
         |> put_flash(:info, "Certificate layout updated successfully.")}

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
         |> put_flash(:info, "Certificate file removed successfully.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to remove the certificate file.")}

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

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user) do
      case Accounts.change_user_email(user, user_params) do
        %{valid?: true} = changeset ->
          Accounts.deliver_user_update_email_instructions(
            Ecto.Changeset.apply_action!(changeset, :insert),
            user.email,
            &url(~p"/users/settings/confirm-email/#{&1}")
          )

          info = "A link to confirm your email change has been sent to the new address."
          {:noreply, socket |> put_flash(:info, info)}

        changeset ->
          {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_recent_sign_in(socket)}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user) do
      case Accounts.change_user_password(user, user_params) do
        %{valid?: true} = changeset ->
          {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

        changeset ->
          {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_recent_sign_in(socket)}
    end
  end

  defp require_recent_sign_in(socket) do
    put_flash(socket, :error, "Please sign in again before changing your email or password.")
  end

  defp profile_attrs(user_params) do
    Map.take(user_params, ["full_name", "employee_number"])
  end

  defp office_name(%{office: office}) when not is_nil(office), do: office.name
  defp office_name(_user), do: "Not assigned"

  defp division_name(%{office: %{division: division}}) when not is_nil(division),
    do: division.name

  defp division_name(_user), do: "Not assigned"

  defp load_user_settings(socket, user) do
    default_certificate_layout_setting = Certificates.get_default_certificate_layout_setting()

    socket
    |> assign(:current_email, user.email)
    |> assign(:profile_form, to_form(Accounts.change_user_profile(user)))
    |> assign_saved_certificate_layout(default_certificate_layout_setting)
  end

  defp assign_saved_certificate_layout(socket, layout_setting) do
    socket
    |> assign(
      :certificate_layout_form,
      to_form(Certificates.change_default_certificate_layout())
    )
    |> assign(
      :certificate_layout_preview,
      Certificates.default_certificate_layout(layout_setting)
    )
  end

  defp merge_uploaded_certificate_layout_asset(socket, params) do
    uploaded_asset_paths = []

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
        {params, uploaded_asset_paths}

      [asset_attrs] ->
        stored_path = Map.fetch!(asset_attrs, "__stored_path__")

        merged_params =
          params
          |> Map.merge(Map.drop(asset_attrs, ["__stored_path__"]))

        {merged_params, [stored_path]}
    end
  end

  defp cleanup_uploaded_assets(paths) do
    Enum.each(paths, &File.rm/1)
  end

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
    normalized_type =
      case client_type do
        value when is_binary(value) and value != "" -> value
        _value -> MIME.from_path(client_name)
      end

    normalized_type || MIME.from_path(client_name)
  end

  defp certificate_asset_storage_path(public_path) do
    Application.app_dir(:tracms, "priv/static" <> public_path)
  end

  defp upload_error_message(:too_large), do: "File is too large."
  defp upload_error_message(:not_accepted), do: "File type is not supported."
  defp upload_error_message(:too_many_files), do: "Only one file can be uploaded."
  defp upload_error_message(_error), do: "Upload failed."
end
