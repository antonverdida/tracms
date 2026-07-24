defmodule TracmsWeb.Router do
  use TracmsWeb, :router

  import TracmsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TracmsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_training_manager do
    plug TracmsWeb.TrainingManagerAuth, :require_training_manager
  end

  scope "/", TracmsWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", TracmsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tracms, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TracmsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TracmsWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/dashboard", PageController, :dashboard
    get "/my/certificates/:id/print", CertificateDocumentController, :participant_print
    get "/my/certificates/:id/export", CertificateDocumentController, :participant_export

    live_session :require_authenticated_user,
      on_mount: [{TracmsWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/catalog/trainings", RegistrationLive.Catalog, :index
      live "/catalog/trainings/:id", RegistrationLive.Show, :show
      live "/my/registrations", RegistrationLive.MyIndex, :index
      live "/my/certificates", CertificateLive.MyIndex, :index
      live "/my/certificates/:id", CertificateLive.Show, :show
      live "/my/registrations/:registration_id/evaluation", RegistrationLive.Evaluation, :edit
    end

    live_session :training_management,
      on_mount: [
        {TracmsWeb.UserAuth, :require_authenticated},
        {TracmsWeb.TrainingLive.Auth, :require_training_manager}
      ] do
      live "/trainings", TrainingLive.Index, :index
      live "/reports", TrainingLive.Reports, :index
      live "/trainings/new", TrainingLive.Form, :new
      live "/trainings/:id/edit", TrainingLive.Form, :edit
      live "/trainings/:id", TrainingLive.Show, :show
      live "/trainings/:training_id/integrations", TrainingLive.Integrations, :index
      live "/trainings/:training_id/registrations", TrainingLive.Registrations, :index
      live "/trainings/:training_id/attendance", TrainingLive.Attendance, :index
      live "/trainings/:training_id/completion", TrainingLive.Completion, :index
      live "/trainings/:training_id/certificates", TrainingLive.Certificates, :index

      live "/trainings/:training_id/certificates/:certificate_id",
           TrainingLive.CertificateShow,
           :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TracmsWeb do
    pipe_through [:browser, :require_authenticated_user, :require_training_manager]

    get "/trainings/:training_id/certificates/:certificate_id/print",
        CertificateDocumentController,
        :manager_print

    get "/trainings/:training_id/certificates/:certificate_id/export",
        CertificateDocumentController,
        :manager_export
  end

  scope "/", TracmsWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TracmsWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
