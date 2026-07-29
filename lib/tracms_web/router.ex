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
    get "/verify/certificates", CertificateVerificationController, :index
    get "/verify/certificates/:certificate_number", CertificateVerificationController, :show
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
    get "/certificates/:id/print", CertificateDocumentController, :participant_print
    get "/certificates/:id/export", CertificateDocumentController, :participant_export

    live_session :require_authenticated_user,
      on_mount: [{TracmsWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/catalog/trainings", RegistrationLive.Catalog, :index
      live "/catalog/trainings/:id", RegistrationLive.Show, :show
      live "/my/registrations", RegistrationLive.MyIndex, :index
      live "/certificates", CertificateLive.MyIndex, :index
      live "/certificates/:id", CertificateLive.Show, :show
      live "/my/registrations/:registration_id/evaluation", RegistrationLive.Evaluation, :edit
      live "/documents", PortalLive.Documents, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TracmsWeb do
    pipe_through [:browser, :require_authenticated_user, :require_training_manager]

    get "/certificates/trainings/:training_id/download-all",
        CertificateDocumentController,
        :manager_bulk_export

    live_session :training_management,
      on_mount: [
        {TracmsWeb.UserAuth, :require_authenticated},
        {TracmsWeb.TrainingLive.Auth, :require_training_manager}
      ] do
      live "/trainings", TrainingLive.Index, :index
      live "/registrations", TrainingLive.RegistrationManagement, :index
      live "/reports", TrainingLive.Reports, :index
      live "/google-integration", PortalLive.GoogleIntegration, :index
      live "/trainings/new", TrainingLive.Form, :new
      live "/trainings/:id/edit", TrainingLive.Form, :edit
      live "/trainings/:id", TrainingLive.Show, :show
      live "/registrations/trainings/:training_id", TrainingLive.RegistrationRegister, :index
      live "/trainings/:training_id/integrations", TrainingLive.Integrations, :index
      live "/trainings/:training_id/registrations", TrainingLive.Registrations, :index
      live "/trainings/:training_id/completion", TrainingLive.Completion, :index
      live "/certificates/trainings/:training_id", TrainingLive.Certificates, :index

      live "/certificates/trainings/:training_id/:certificate_id",
           TrainingLive.CertificateShow,
           :show
    end
  end

  scope "/", TracmsWeb do
    pipe_through [:browser, :require_authenticated_user, :require_training_manager]

    get "/certificates/trainings/:training_id/:certificate_id/print",
        CertificateDocumentController,
        :manager_print

    get "/certificates/trainings/:training_id/:certificate_id/export",
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
