defmodule Changeban.GameServer do
  use GenServer

  alias Changeban.{Game}

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

  def stats(game_name) do
    GenServer.call(via_tuple(game_name), :stats)
  end

  def get_player(game_name, player_id) do
    GenServer.call(via_tuple(game_name), {:get_player, player_id})
  end

  def add_player(game_name, initials) do
    GenServer.call(via_tuple(game_name), {:add_player, initials})
  end

  def remove_player(game_name, player_id) do
    GenServer.call(via_tuple(game_name), {:remove_player, player_id})
  end

  def set_wip(game_name, wip_type, limit) do
    GenServer.call(via_tuple(game_name), {:set_wip, wip_type, limit})
  end

  def joinable?(nil), do: false
  def joinable?(game_name) do
    if game_exists?(game_name) do
      GenServer.call(via_tuple(game_name), {:joinable?})
    else
      false
    end
  end

  def start_game(game_name) do
    GenServer.call(via_tuple(game_name), {:start_game})
  end

  def move(game_name, type, item_id, player_id) do
    GenServer.call(via_tuple(game_name), {:act, type, item_id, player_id})
  end

  def game_exists?(nil), do: false
  def game_exists?(game_name) do
    not Enum.empty?(Registry.lookup(Changeban.GameRegistry, game_name))
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

  def handle_call({:add_player, initials}, _from, game) do
    case Game.add_player(game, initials) do
      {:ok, player_id, updated_game} -> {:reply, {:ok, player_id, updated_game}, updated_game, @timeout}
      {:error, msg} -> {:reply, {:error, msg}, game, @timeout}
    end
  end

  def handle_call({:remove_player, player_id}, _from, game) do
    updated_game = Game.remove_player(game, player_id)
    {:reply, updated_game, updated_game, @timeout}
  end

  def handle_call({:joinable?}, _from, game) do
    {:reply, Game.joinable?(game), game, @timeout}
  end

  def handle_call({:get_player, player_id}, _from, game) do
    {:reply, Game.get_player(game, player_id), game, @timeout}
  end

  def handle_call({:start_game}, _from, game) do
    updated_game = Game.start_game(game)
    {:reply, updated_game, updated_game, @timeout}
  end

  # :start, :move, :block, :unblock, :reject
  def handle_call({:act, act, item_id, player_id}, _from, game) do
    updated_game = Game.exec_action(game, act, item_id, player_id)
    :ets.insert(:games_table, {my_game_name(), updated_game})
    {:reply, view_game(updated_game), updated_game, @timeout}
  end

  def handle_call(:view, _from, game) do
    {:reply, view_game(game), game, @timeout}
  end

  def handle_call(:stats, _from, game) do
    {:reply, Game.stats(game), game, @timeout}
  end

  def handle_call({:set_wip, wip_type, limit}, _from, game) do
    updated_game = Game.set_wip(game, wip_type, limit)
    {:reply, updated_game, updated_game, @timeout}
  end

  def handle_info(:timeout, game) do
    {:stop, {:shutdown, :timeout}, game}
  end

  def terminate({:shutdown, :timeout}, _game) do
    :ets.delete(:games_table, my_game_name())
    :ok
  end

  def terminate(_reason, _game), do: :ok

  # def view_game(game) do
  #   {Enum.group_by(game.items, &(&1.state)),
  #    game.players,
  #    game.turn,
  #    game.score,
  #    game.state,
  #    game.wip_limits}
  # end

  def view_game(game) do
    {collate_items(game.items),
     game.players,
     game.turn,
     game.score,
     game.state,
     game.wip_limits}
  end

  defp collate_items(items) do
    new_items = items
    |> Enum.group_by(&(&1.state))
    |> Enum.map(fn {state, items} -> {state, Enum.sort(items, &(&1.moved <= &2.moved))} end )
    |> Enum.into(%{})
    IO.puts("\n\n new items #{inspect new_items, pretty: true}")
    new_items
  end

  defp my_game_name do
    Registry.keys(Changeban.GameRegistry, self()) |> List.first
  end
end
