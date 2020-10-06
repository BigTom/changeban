defmodule GamesRoomWeb.Router do
  use GamesRoomWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GamesRoomWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger, log: :debug
    plug :fetch_session
  end

  scope "/", GamesRoomWeb do
    pipe_through :browser

    live "/", ChangebanLive, :index
    # live "/login", LoginLive, :index
    # live "/login/:id", LoginLive, :index
    live "/changeban", ChangebanLive, :index
  end

  scope "/api", GamesRoomWeb do
    pipe_through :api

    post "/session", SessionController, :set
  end

  # Other scopes may use custom stacks.
  # scope "/api", GamesRoomWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: GamesRoomWeb.Telemetry
    end
  end
end
