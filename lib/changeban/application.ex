defmodule Changeban.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ChangebanWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Changeban.PubSub},
      Changeban.Presence,
      # Start the Endpoint (http/https)
      ChangebanWeb.Endpoint,
      # Start a worker by calling: Changeban.Worker.start_link(arg)
      # {Changeban.Worker, arg}
      {Registry, keys: :unique, name: Changeban.GameRegistry},
      Changeban.GameSupervisor
    ]

    :ets.new(:games_table, [:public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Changeban.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChangebanWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
