defmodule TracmsWeb.RegistrationLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Evaluations
  alias Tracms.Registrations

  @impl true
  def mount(%{"id" => training_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Training Details")
     |> assign(:training_id, training_id)
     |> load_page()}
  end

  @impl true
  def handle_event("validate", %{"registration_request" => params}, socket) do
    {:noreply, assign(socket, :request_form, to_form(params, as: :registration_request))}
  end

  def handle_event("register", %{"registration_request" => params}, socket) do
    case Registrations.register_user_for_training(
           socket.assigns.current_scope,
           socket.assigns.training_activity.id,
           params
         ) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration submitted successfully.")
         |> load_page()}

      {:error, :already_registered} ->
        {:noreply, put_flash(socket, :error, "You are already registered for this training.")}

      {:error, :capacity_reached} ->
        {:noreply, put_flash(socket, :error, "This training has reached its maximum capacity.")}

      {:error, :registration_not_open} ->
        {:noreply,
         put_flash(socket, :error, "Registration for this training has not opened yet.")}

      {:error, :registration_closed} ->
        {:noreply, put_flash(socket, :error, "Registration for this training is already closed.")}

      {:error, :not_published} ->
        {:noreply, put_flash(socket, :error, "This training is not open for registration.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to submit your registration right now.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav={@active_nav}
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Participant training record"
          title={@training_activity.title}
          copy={"#{@training_activity.category} • #{@training_activity.training_type}"}
        >
          <:actions>
            <.button navigate={back_path(@registration)} variant="ghost">
              {back_label(@registration)}
            </.button>
            <.button :if={@registration} navigate={~p"/my/registrations"} variant="secondary">
              My registrations
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <div class="content-grid">
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Training description"
              title="Program overview"
              meta="Participant-facing details for registration and preparation."
            />

            <div class="space-y-5">
              <p class="section-copy whitespace-pre-line">{@training_activity.description}</p>

              <div>
                <h2 class="section-title">Objectives</h2>
                <p class="section-copy whitespace-pre-line">{@training_activity.objectives}</p>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Training information"
              title="Participant details"
              meta="Key activity information used for registration, attendance, and completion."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Organizer</div>
                <div class="feature-copy">{@training_activity.organizer}</div>
              </div>
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
                  {@training_activity.total_hours} hour(s) • {duration_days(@training_activity)} day(s)
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Modality</div>
                <div class="feature-copy">{format_modality(@training_activity.modality)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Venue</div>
                <div class="feature-copy">{@training_activity.venue}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Capacity</div>
                <div class="feature-copy">
                  {@active_registration_count} / {@training_activity.max_capacity} active registration slots
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Registration deadline</div>
                <div class="feature-copy">
                  {format_datetime(@training_activity.registration_deadline)}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Registration process</div>
                <div class="feature-copy">{registration_process_label(@training_activity)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Certificate type</div>
                <div class="feature-copy">{@training_activity.certificate_type}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Attendance process</div>
                <div class="feature-copy">{attendance_process_label(@training_activity)}</div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Requirements"
              title="Eligibility and participation"
              meta="Registration and completion expectations for DepEd personnel."
            />

            <div class="portal-workflow-list">
              <div class="portal-workflow-item portal-workflow-item-green">
                <div>
                  <p class="portal-workflow-label">Target participants</p>
                  <p class="portal-workflow-copy whitespace-pre-line">
                    {@training_activity.target_participants}
                  </p>
                </div>
                <span class="portal-workflow-value">Eligible</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-blue">
                <div>
                  <p class="portal-workflow-label">Participant qualification</p>
                  <p class="portal-workflow-copy whitespace-pre-line">
                    {@training_activity.participant_qualification}
                  </p>
                </div>
                <span class="portal-workflow-value">Required</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-amber">
                <div>
                  <p class="portal-workflow-label">Attendance requirement</p>
                  <p class="portal-workflow-copy">
                    Participants must meet the minimum attendance threshold for completion.
                  </p>
                </div>
                <span class="portal-workflow-value">
                  {@training_activity.minimum_attendance_percentage}%
                </span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-slate">
                <div>
                  <p class="portal-workflow-label">Evaluation requirement</p>
                  <p class="portal-workflow-copy">
                    {evaluation_requirement_copy(@training_activity.evaluation_required)}
                  </p>
                </div>
                <span class="portal-workflow-value">
                  {if @training_activity.evaluation_required, do: "Required", else: "Optional"}
                </span>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <%= if @registration do %>
              <.portal_panel_header
                eyebrow="My participation"
                title="Registration progress"
                meta="Your current workflow status for this training."
              />

              <div class="portal-workflow-list">
                <div class={[
                  "portal-workflow-item",
                  "portal-workflow-item-#{registration_tone(@registration.status)}"
                ]}>
                  <div>
                    <p class="portal-workflow-label">Registration status</p>
                    <p class="portal-workflow-copy">{registration_status_copy(@registration)}</p>
                  </div>
                  <span class="portal-workflow-value">
                    {Registrations.format_status(@registration.status)}
                  </span>
                </div>
                <div class={[
                  "portal-workflow-item",
                  "portal-workflow-item-#{evaluation_tone(@evaluation_state)}"
                ]}>
                  <div>
                    <p class="portal-workflow-label">Evaluation status</p>
                    <p class="portal-workflow-copy">{@evaluation_state.copy}</p>
                  </div>
                  <span class="portal-workflow-value">{@evaluation_state.label}</span>
                </div>
                <div class={[
                  "portal-workflow-item",
                  "portal-workflow-item-#{certificate_tone(@certificate_state)}"
                ]}>
                  <div>
                    <p class="portal-workflow-label">Certificate status</p>
                    <p class="portal-workflow-copy">{@certificate_state.copy}</p>
                  </div>
                  <span class="portal-workflow-value">{@certificate_state.label}</span>
                </div>
              </div>

              <div class="mt-6 flex flex-wrap justify-end gap-3">
                <.button
                  :if={@evaluation_action}
                  navigate={~p"/my/registrations/#{@registration.id}/evaluation"}
                  variant="secondary"
                >
                  {@evaluation_action}
                </.button>
                <.button
                  :if={@training_activity.attendance_form_url}
                  href={@training_activity.attendance_form_url}
                  target="_blank"
                  rel="noreferrer"
                  variant="secondary"
                >
                  Open attendance form
                </.button>
                <.button
                  :if={@certificate}
                  navigate={~p"/certificates/#{@certificate.id}"}
                >
                  View certificate
                </.button>
              </div>
            <% else %>
              <%= if external_registration?(@training_activity) do %>
                <.portal_panel_header
                  eyebrow="Registration request"
                  title="Official external registration"
                  meta="This training collects participant applications through a coordinator-issued form."
                />

                <div class="portal-workflow-list">
                  <div class="portal-workflow-item portal-workflow-item-blue">
                    <div>
                      <p class="portal-workflow-label">External collection workflow</p>
                      <p class="portal-workflow-copy">
                        Complete the official registration form provided for this activity. TRACMS remains the official record for review, approval, completion, certificates, and reports after your submission is processed.
                      </p>
                    </div>
                    <span class="portal-workflow-value">Official form</span>
                  </div>
                  <div class="portal-workflow-item portal-workflow-item-slate">
                    <div>
                      <p class="portal-workflow-label">What happens next</p>
                      <p class="portal-workflow-copy">
                        After the training office validates the external responses, your participation record will appear in TRACMS for status tracking and certificate release.
                      </p>
                    </div>
                    <span class="portal-workflow-value">Review first</span>
                  </div>
                </div>

                <div class="dashboard-action-grid mt-6">
                  <div class="feature-card">
                    <div class="feature-title">TRACMS account name</div>
                    <div class="feature-copy">{@participant_profile.full_name}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">DepEd email</div>
                    <div class="feature-copy">{@participant_profile.email}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">Employee number</div>
                    <div class="feature-copy">{@participant_profile.employee_number}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">Office and role</div>
                    <div class="feature-copy">
                      {@participant_profile.office_label} • {@participant_profile.role_label}
                    </div>
                  </div>
                </div>

                <div class="mt-6 flex flex-wrap justify-end gap-3">
                  <.button navigate={~p"/catalog/trainings"} variant="ghost">Back to catalog</.button>
                  <.button
                    href={@training_activity.registration_form_url}
                    target="_blank"
                    rel="noreferrer"
                  >
                    Open official registration form
                  </.button>
                </div>
              <% else %>
                <.portal_panel_header
                  eyebrow="Registration request"
                  title="Submit registration"
                  meta="Your TRACMS profile is used as the participant record for this request."
                />

                <div class="dashboard-action-grid">
                  <div class="feature-card">
                    <div class="feature-title">Full name</div>
                    <div class="feature-copy">{@participant_profile.full_name}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">Employee number</div>
                    <div class="feature-copy">{@participant_profile.employee_number}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">Email address</div>
                    <div class="feature-copy">{@participant_profile.email}</div>
                  </div>
                  <div class="feature-card">
                    <div class="feature-title">Office and role</div>
                    <div class="feature-copy">
                      {@participant_profile.office_label} • {@participant_profile.role_label}
                    </div>
                  </div>
                </div>

                <.form
                  for={@request_form}
                  id="participant-registration-form"
                  phx-change="validate"
                  phx-submit="register"
                  class="mt-6"
                >
                  <.input
                    field={@request_form[:special_requirements]}
                    type="textarea"
                    label="Special requirements or accommodation notes"
                    rows="5"
                  />

                  <div class="mt-6 flex flex-wrap justify-end gap-3">
                    <.button navigate={~p"/catalog/trainings"} variant="ghost">
                      Back to catalog
                    </.button>
                    <.button phx-disable-with="Submitting registration...">
                      Submit registration
                    </.button>
                  </div>
                </.form>
              <% end %>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    {training_activity, registration} =
      Registrations.get_participant_training_activity!(
        socket.assigns.current_scope,
        socket.assigns.training_id
      )

    certificate =
      if registration,
        do: Certificates.get_certificate_for_registration(registration.id),
        else: nil

    evaluation_submission =
      if registration, do: Evaluations.get_submission_for_registration(registration.id), else: nil

    active_registration_count = Registrations.active_registration_count(training_activity.id)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:registration, registration)
    |> assign(:certificate, certificate)
    |> assign(:active_registration_count, active_registration_count)
    |> assign(:participant_profile, participant_profile(socket.assigns.current_scope.user))
    |> assign(
      :summary_cards,
      summary_cards(training_activity, registration, certificate, active_registration_count)
    )
    |> assign(:request_form, to_form(%{"special_requirements" => ""}, as: :registration_request))
    |> assign(
      :evaluation_state,
      evaluation_state(training_activity, registration, evaluation_submission)
    )
    |> assign(:certificate_state, certificate_state(registration, certificate))
    |> assign(
      :evaluation_action,
      evaluation_action(training_activity, registration, evaluation_submission)
    )
    |> assign(:active_nav, active_nav(registration))
  end

  defp summary_cards(training_activity, registration, certificate, active_registration_count) do
    [
      summary_card(
        "Registration",
        registration_label(registration, training_activity),
        "Current participant registration state for this training"
      ),
      summary_card(
        "Schedule",
        format_date(training_activity.starts_on),
        "Ends on #{format_date(training_activity.ends_on)}"
      ),
      summary_card(
        "Slots",
        "#{active_registration_count} / #{training_activity.max_capacity}",
        "Submitted, approved, or waitlisted registrations"
      ),
      summary_card(
        "Certificate",
        if(certificate, do: "Issued", else: "Pending"),
        certificate_meta(registration, certificate)
      )
    ]
  end

  defp registration_label(nil, training_activity) do
    if external_registration?(training_activity),
      do: "External form",
      else: "Open for registration"
  end

  defp registration_label(registration, _training_activity),
    do: Registrations.format_status(registration.status)

  defp certificate_meta(_registration, %{certificate_number: certificate_number}),
    do: "Certificate No. #{certificate_number}"

  defp certificate_meta(%{status: :approved}, nil), do: "Available after completion and release"
  defp certificate_meta(_registration, nil), do: "Not yet available"

  defp participant_profile(user) do
    %{
      full_name: user.full_name || user.email,
      employee_number: user.employee_number || "Not yet provided",
      email: user.email,
      office_label:
        if(user.office && user.office.name, do: user.office.name, else: "No office assigned"),
      role_label: if(user.role && user.role.name, do: user.role.name, else: "No role assigned")
    }
  end

  defp evaluation_state(_training_activity, nil, _evaluation_submission) do
    %{
      label: "Not available",
      copy: "Evaluation becomes available after your registration is approved."
    }
  end

  defp evaluation_state(training_activity, _registration, _evaluation_submission)
       when not training_activity.evaluation_required do
    %{
      label: "Not required",
      copy: "This training does not require a participant evaluation for completion."
    }
  end

  defp evaluation_state(_training_activity, %{status: :approved}, nil) do
    %{label: "Pending", copy: "Submit your evaluation after attending to complete the workflow."}
  end

  defp evaluation_state(_training_activity, %{status: :approved}, _evaluation_submission) do
    %{label: "Submitted", copy: "Your evaluation is already recorded and can still be updated."}
  end

  defp evaluation_state(_training_activity, _registration, _evaluation_submission) do
    %{label: "Waiting for approval", copy: "Evaluation opens only after registration approval."}
  end

  defp certificate_state(nil, _certificate) do
    %{
      label: "Not available",
      copy:
        "Certificate release happens only after registration, attendance, and completion processing."
    }
  end

  defp certificate_state(_registration, %{certificate_number: certificate_number}) do
    %{label: "Issued", copy: "Certificate No. #{certificate_number} is already on file."}
  end

  defp certificate_state(%{status: :approved}, nil) do
    %{
      label: "Awaiting issuance",
      copy: "Certificate release follows attendance and evaluation completion checks."
    }
  end

  defp certificate_state(_registration, nil) do
    %{
      label: "Not available",
      copy: "Certificate release begins only after approval and training completion."
    }
  end

  defp evaluation_action(training_activity, %{status: :approved}, evaluation_submission)
       when training_activity.evaluation_required do
    if evaluation_submission, do: "Update evaluation", else: "Submit evaluation"
  end

  defp evaluation_action(_training_activity, _registration, _evaluation_submission), do: nil

  defp registration_status_copy(registration) do
    case registration.status do
      :submitted -> "Your request is awaiting review by the training management team."
      :approved -> "You are confirmed for participation in this training activity."
      :waitlisted -> "Your request is on hold pending slot availability or reviewer action."
      :rejected -> "Your request was not approved for this training activity."
      :withdrawn -> "You withdrew this registration from the participant workflow."
    end
  end

  defp evaluation_requirement_copy(true),
    do: "A participant evaluation is required before completion can be counted."

  defp evaluation_requirement_copy(false),
    do: "This training can be completed without a participant evaluation form."

  defp external_registration?(training_activity),
    do: not is_nil(training_activity.registration_form_url)

  defp registration_process_label(training_activity) do
    if external_registration?(training_activity) do
      "Coordinator-issued external registration form"
    else
      "TRACMS portal registration"
    end
  end

  defp attendance_process_label(training_activity) do
    if training_activity.attendance_form_url do
      "External attendance form available after coordination"
    else
      "Attendance managed in the TRACMS workflow"
    end
  end

  defp active_nav(nil), do: "catalog"
  defp active_nav(_registration), do: "registrations"

  defp back_path(nil), do: ~p"/catalog/trainings"
  defp back_path(_registration), do: ~p"/my/registrations"

  defp back_label(nil), do: "Back to catalog"
  defp back_label(_registration), do: "Back to registrations"

  defp registration_tone(:approved), do: "green"
  defp registration_tone(:submitted), do: "blue"
  defp registration_tone(:waitlisted), do: "amber"
  defp registration_tone(:rejected), do: "rose"
  defp registration_tone(:withdrawn), do: "slate"
  defp registration_tone(_status), do: "slate"

  defp evaluation_tone(%{label: "Submitted"}), do: "green"
  defp evaluation_tone(%{label: "Pending"}), do: "amber"
  defp evaluation_tone(%{label: "Waiting for approval"}), do: "blue"
  defp evaluation_tone(_state), do: "slate"

  defp certificate_tone(%{label: "Issued"}), do: "green"
  defp certificate_tone(%{label: "Awaiting issuance"}), do: "amber"
  defp certificate_tone(_state), do: "slate"

  defp duration_days(training_activity) do
    Date.diff(training_activity.ends_on, training_activity.starts_on) + 1
  end
end
