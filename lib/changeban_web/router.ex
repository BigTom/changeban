defmodule ChangebanWeb.Router do
  use ChangebanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ChangebanWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger, log: :debug
    plug :fetch_session
  end

  scope "/", ChangebanWeb do
    pipe_through :browser

    # TODO # get "/new_stats", StatsController, :stats

    live "/", ChangebanJoinLive, :index
    live "/join", ChangebanJoinLive, :index
    live "/stats/:game_name", ChangebanStatsLive, :index
    live "/game/:game_name/:player_id/:player_initials", ChangebanLive, :index
    live "/game/:game_name", ChangebanLive, :index
  end

  scope "/api", ChangebanWeb do
    pipe_through :api
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChangebanWeb do
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
      live_dashboard "/dashboard", metrics: ChangebanWeb.Telemetry
    end
  end
end
