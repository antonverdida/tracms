defmodule TracmsWeb.RegistrationLive.Evaluation do
  use TracmsWeb, :live_view

  alias Tracms.Evaluations
  alias Tracms.Evaluations.EvaluationSubmission

  @impl true
  def mount(%{"registration_id" => registration_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Training Evaluation")
     |> assign(:registration_id, registration_id)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load_page(socket)}
  end

  @impl true
  def handle_event("validate", %{"evaluation_submission" => params}, socket) do
    changeset =
      socket.assigns.evaluation_submission
      |> Evaluations.change_submission(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "evaluation_submission"))}
  end

  def handle_event("save", %{"evaluation_submission" => params}, socket) do
    case Evaluations.submit_evaluation(
           socket.assigns.current_scope,
           socket.assigns.registration.id,
           params
         ) do
      {:ok, _submission} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evaluation submitted successfully.")
         |> push_navigate(to: ~p"/my/registrations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "evaluation_submission"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="registrations"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Participant evaluation"
          title={@registration.training_activity.title}
          copy="Submit your training feedback to complete the evaluation requirement for this activity."
        >
          <:actions>
            <.button navigate={~p"/my/registrations"} variant="ghost">
              Back to registrations
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="content-grid">
          <article class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Evaluation form"
              title={if @existing_submission?, do: "Update evaluation", else: "Submit evaluation"}
              meta="Share your overall rating, key feedback, and how you plan to apply the training."
            />

            <.form
              for={@form}
              id="evaluation-form"
              phx-change="validate"
              phx-submit="save"
              class="mt-6"
            >
              <.input
                field={@form[:overall_rating]}
                type="select"
                label="Overall rating"
                options={EvaluationSubmission.rating_options()}
              />
              <.input
                field={@form[:feedback]}
                type="textarea"
                label="Key feedback"
                rows="6"
              />
              <.input
                field={@form[:application_plan]}
                type="textarea"
                label="How will you apply this training?"
                rows="6"
              />

              <div class="mt-6 flex flex-wrap justify-end gap-3">
                <.button navigate={~p"/my/registrations"} variant="ghost">Cancel</.button>
                <.button phx-disable-with="Saving evaluation...">
                  {if @existing_submission?, do: "Save changes", else: "Submit evaluation"}
                </.button>
              </div>
            </.form>
          </article>

          <article class="panel panel-muted portal-list-panel">
            <.portal_panel_header eyebrow="Training context" title="Completion requirement" />

            <div class="stack">
              <div class="feature-card">
                <div class="feature-title">Training schedule</div>
                <div class="feature-copy">
                  {format_date(@registration.training_activity.starts_on)} to {format_date(
                    @registration.training_activity.ends_on
                  )}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Minimum attendance</div>
                <div class="feature-copy">
                  {@registration.training_activity.minimum_attendance_percentage}%
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Evaluation requirement</div>
                <div class="feature-copy">
                  This training requires a participant evaluation before completion is counted.
                </div>
              </div>
            </div>
          </article>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    registration =
      Evaluations.get_user_registration_for_evaluation!(
        socket.assigns.current_scope,
        socket.assigns.registration_id
      )

    evaluation_submission =
      Evaluations.get_submission_for_registration(registration.id) ||
        %EvaluationSubmission{registration_id: registration.id}

    socket
    |> assign(:registration, registration)
    |> assign(:evaluation_submission, evaluation_submission)
    |> assign(:existing_submission?, not is_nil(evaluation_submission.id))
    |> assign(:summary_cards, evaluation_summary_cards(registration, evaluation_submission))
    |> assign(
      :form,
      to_form(Evaluations.change_submission(evaluation_submission), as: "evaluation_submission")
    )
  end

  defp evaluation_summary_cards(registration, evaluation_submission) do
    [
      summary_card(
        "Schedule",
        format_date(registration.training_activity.starts_on),
        "Ends on #{format_date(registration.training_activity.ends_on)}"
      ),
      summary_card(
        "Minimum attendance",
        "#{registration.training_activity.minimum_attendance_percentage}%",
        "Required completion threshold"
      ),
      summary_card("Evaluation required", "Yes", "Feedback must be submitted for completion"),
      summary_card(
        "Submission status",
        if(is_nil(evaluation_submission.id), do: "Pending", else: "Submitted"),
        if(
          is_nil(evaluation_submission.id),
          do: "You still need to complete this form",
          else: "Your feedback can still be updated"
        )
      )
    ]
  end
end
