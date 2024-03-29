defmodule PriceSpotterWeb.Router do
  use PriceSpotterWeb, :router

  import PriceSpotterWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PriceSpotterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :user do
    plug PriceSpotterWeb.EnsureRolePlug, [:admin, :user]
  end

  pipeline :admin do
    plug PriceSpotterWeb.EnsureRolePlug, :admin
  end

  scope "/", PriceSpotterWeb do
    pipe_through [:browser]

    get "/", PageController, :home

    scope "/admin/marketplaces", Admin.Marketplaces do
      pipe_through [:require_authenticated_user]

      scope "/products" do
        scope "/new" do
          pipe_through [:admin]
          live "/", ProductLive.Index, :new
        end

        scope "/:id" do
          pipe_through [:admin]
          live "/show/edit", ProductLive.Show, :edit
          live "/edit", ProductLive.Index, :edit
        end

        live "/", ProductLive.Index, :index
        live "/:id", ProductLive.Show, :show
      end

      scope "/suppliers" do
        pipe_through [:admin]

        live "/", SupplierLive.Index, :index
        live "/new", SupplierLive.Index, :new
        live "/:id/edit", SupplierLive.Index, :edit

        live "/:id", SupplierLive.Show, :show
        live "/:id/show/edit", SupplierLive.Show, :edit
      end

      scope "/users_suppliers" do
        pipe_through [:admin]

        live "/", UserSupplierLive.Index, :index
        live "/new", UserSupplierLive.Index, :new
        live "/:id/edit", UserSupplierLive.Index, :edit

        live "/:id", UserSupplierLive.Show, :show
        live "/:id/show/edit", UserSupplierLive.Show, :edit
      end
    end

    scope "/admin/accounts", Admin.Accounts do
      pipe_through [:require_authenticated_user, :admin]

      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.Index, :new
      live "/users/:id/edit", UserLive.Index, :edit

      live "/users/:id", UserLive.Show, :show
      live "/users/:id/show/edit", UserLive.Show, :edit
    end

    get "/products/export", ExportController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", PriceSpotterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:price_spotter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PriceSpotterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PriceSpotterWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [
        {PriceSpotterWeb.UserAuth, :redirect_if_user_is_authenticated}
      ] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit

      # live "/users/register", UserRegistrationLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", PriceSpotterWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PriceSpotterWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings/confirm_email/:token",
           UserSettingsLive,
           :confirm_email

      pipe_through [:admin]
      live "/users/settings", UserSettingsLive, :edit
    end
  end

  scope "/", PriceSpotterWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PriceSpotterWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
