defmodule Changeban.GameSupervisor do
  @moduledoc """
  A supervisor that starts `GameServer` processes dynamically.
  """
  require Logger

  use DynamicSupervisor

  alias Changeban.GameServer

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a `GameServer` process and supervises it.
  """
  def create_game(game_name) do
    child_spec = %{
      id: GameServer,
      start: {GameServer, :start_link, [game_name]},
      restart: :transient
    }

    Logger.debug("game supervisor: #{inspect(GenServer.whereis(Changeban.GameSupervisor))}")
    Logger.debug("childspec: #{inspect(child_spec)}")

    resp = DynamicSupervisor.start_child(__MODULE__, child_spec)
    Logger.debug("resp: #{inspect(resp)}")
    resp
  end

  @doc """
  Terminates the `GameServer` process normally. It won't be restarted.
  """
  def close_game(game_name) do
    :ets.delete(:games_table, game_name)

    child_pid = GameServer.game_pid(game_name)
    DynamicSupervisor.terminate_child(__MODULE__, child_pid)
  end
end
