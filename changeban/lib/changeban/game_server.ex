defmodule Changeban.GameServer do
  use GenServer

  alias Changeban.{Game, Item}

  require Logger
  @timeout :timer.hours(1)


  def start_link(game_name) do
    GenServer.start_link(__MODULE__,
                         game_name,
                         name: via_tuple(game_name))
  end

  def view(game_name) do
    GenServer.call(via_tuple(game_name), :view)
  end

  def get_red_options(game_name, player_id) do
    GenServer.call(via_tuple(game_name), {:get_red_options, player_id})
  end
  def get_black_options(game_name, player_id) do
    GenServer.call(via_tuple(game_name), {:get_black_options, player_id})
  end

  def move(game_name, type, item_id, player_id) do
    GenServer.call(via_tuple(game_name), {:move, type, item_id, player_id})
  end

  @doc """
  Returns a tuple used to register and lookup a game server process by name.
  Changeban.GameRegistry is simply an unique atom for the name, it could be anything
  The Registtry itself is started in the Changeban Application module.
  """
  def via_tuple(game_name) do
    {:via, Registry, {Changeban.GameRegistry, game_name}}
  end

  @doc """
  Returns the `pid` of the game server process registered under the
  given `game_name`, or `nil` if no process is registered.
  """
  def game_pid(game_name) do
    game_name
    |> via_tuple()
    |> GenServer.whereis()
  end


  # Server Callbacks

  def init(game_name) do
    game =
      case :ets.lookup(:games_table, game_name) do
        [] ->
          game = Changeban.Game.new()
          :ets.insert(:games_table, {game_name, game})
          game

        [{^game_name, game}] ->
          game
      end

    Logger.info("Spawned game server process named '#{game_name}'.")

    {:ok, game, @timeout}
  end

  def handle_call({:get_red_options, player_id}, _from, game) do
    {:reply, Game.red_options(game, player_id), game, @timeout}
  end
  def handle_call({:get_black_options, player_id}, _from, game) do
    {:reply, Game.black_options(game, player_id), game, @timeout}
  end

  def handle_call({:move, :act, item_id, player_id}, _from, game) do
    make_move(&Item.progress/2, item_id, player_id, game)
  end
  def handle_call({:move, :help, item_id, player_id}, _from, game) do
    make_move(&Item.help/2, item_id, player_id, game)
  end
  def handle_call({:move, :block, item_id, player_id}, _from, game) do
    make_move(&Item.block/2, item_id, player_id, game)
  end

  def handle_call(:view, _from, game) do
    {:reply, view_game(game), game, @timeout}
  end

  def handle_info(:timeout, game) do
    {:stop, {:shutdown, :timeout}, game}
  end

  def terminate({:shutdown, :timeout}, _game) do
    :ets.delete(:games_table, my_game_name())
    :ok
  end
  def terminate(_reason, _game), do: :ok

  @doc"""
    This is a DRY method for the :handle_move :act, :help & :block methods
  """
  def make_move(move_fun, item_id, player_id, game) do
    updated_game = Game.exec_action(game, move_fun, item_id, player_id)
    :ets.insert(:games_table, {my_game_name(), updated_game})
    {:reply, view_game(updated_game), updated_game, @timeout}
  end

  def view_game(game) do
    Enum.group_by(game.items, &(&1.state))
  end

  defp my_game_name do
    Registry.keys(Changeban.GameRegistry, self()) |> List.first
  end
end
