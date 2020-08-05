defmodule GamesRoom.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the App State
      GamesRoom.Counter,
      # Start the Telemetry supervisor
      GamesRoomWeb.Telemetry,
      # Start the PubSub system
      GamesRoom.PubSub,
      GamesRoom.Presence,
      # Start the Endpoint (http/https)
      GamesRoomWeb.Endpoint
      # Start a worker by calling: GamesRoom.Worker.start_link(arg)
      # {GamesRoom.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GamesRoom.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GamesRoomWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
