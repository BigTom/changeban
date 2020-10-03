defmodule Changeban.Game do
  require Logger
  @moduledoc """
  Manages the game state.

  A game has:
    players - list of players how can own items
    items - map of item_ids to items

  Score:
    1 per accepted item up to 4 for each color e.g. max 8
    1 point per type in each rejected column e.g. max 8
    1 point for each rejected column with 1 and only one of EACH color e.g. max 4

    Total possible 20

  future
    moves - the list of :red and :black moves
    turn - current turn number
  """
  @max_player_id 4
  @turn_cycle 100
  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  @enforce_keys [:items]
  defstruct players: [], max_players: 0, items: [], score: 0, turn: 0, state: :setup, wip_limits: {:none, 0}, turns: []

  # Valid wip limits:
  # {:none, 0} - default
  # {:std, [n,n,n]}
  # {:con, n}

  alias Changeban.{Game, Item, Player}

  def new() do
    %Game{items: initial_items(16), max_players: (@max_player_id + 1), turns: turns()}
  end

  def new_short_game_for_testing() do
    %Game{items: initial_items(4), max_players: (@max_player_id + 1), turns: turns()}
  end

  def initial_items(nr_items), do: for id <- 0..(nr_items - 1), do: Item.new(id)

  def turns() do
    for _ <- 0..(@turn_cycle - 1), do: Enum.random([:red, :black])
  end

  def add_player(%Game{players: players} = game, initials) do
    new_player_id = player_count(game)
    if new_player_id <= @max_player_id do
      new_player = Player.new(new_player_id, initials)
      {:ok, new_player_id, %{game | players: [new_player | players]}}
    else
      {:error, "Already at max players"}
    end
  end

  def joinable?(%Game{state: state} = game) do
    player_count(game) < @max_player_id + 1
    && state == :setup
  end

  def player_count(%Game{players: players}) do
    Enum.count(players)
  end

  def start_game(%Game{players: []}), do: {:error, "No players"}
  def start_game(%Game{turn: 0, state: :setup} = game), do: new_turn(%{game | state: :running})
  def start_game(game), do: game


  def new_turn(%Game{state: :done} = game), do: game
  def new_turn(%Game{players: players, turn: turn} = game) do
    cond do
      game_over?(game) -> %{game | state: :done}
      all_blocked?(game) ->
        %{game | players: Enum.map(players, &(%{&1 | machine: :red, state: :act, past: nil})), turn: turn + 1}
            |> recalculate_state
      true ->
        %{game | players: Enum.map(players, &(%{&1 | machine: red_or_black(game, &1, turn), state: :act, past: nil})), turn: turn + 1}
            |> recalculate_state
    end
  end

  def red_or_black(%Game{turns: turns, players: players}, %Player{id: player_id}, turn) do
    position = rem(turn * Enum.count(players) + player_id, @turn_cycle)
    Enum.at(turns, position)
  end

  def game_over?(game), do: game_over_all_done(game) # || game_over_single_player_blocked(game)

  def game_over_all_done(%Game{items: items}) do
    Enum.find(items, &Item.active?/1 ) == nil
  end

  @doc"""
    One player, all active items are blocked
  """
  def all_blocked?(%Game{items: items, players: players}) do
    active = items
      |> Enum.filter(&Item.active?/1)
      |> Enum.reject(&Item.blocked?/1)
      |> Enum.count()

    active == 0 && Enum.count(players) == 1
  end

  def get_item(%Game{items: items}, id) do
    items |> Enum.find(& ( &1.id == id))
  end

  def update_game(%Game{items: items, players: players} = game, %Item{} = item, %Player{} = player) do
    items_ =
      items
      |> Enum.filter(& ( &1.id != item.id))    # Take out existing version
      |> List.insert_at(0, item)               # insert new version
      |> Enum.sort_by(& &1.id)                 # make sure the order is maintained

    players_ =
      players
      |> Enum.filter(& ( &1.id != player.id))  # Take out existing version
      |> List.insert_at(0, player)             # insert new version
      |> Enum.sort_by(& &1.id)                 # make sure the order is maintained

      game_ = %{game | items: items_, players: players_}
      recalculate_state(game_)
  end

  def recalculate_state(game) do
    score = calculate_score(game)
    players = recalculate_all_player_options(game)

    game_ = %{game | score: score, players: players}
    case (Enum.find(players, &(&1.state != :done))) do
      nil -> new_turn(game_)
      _ -> game_
    end
  end

  def calculate_score(%Game{items: items}) do
    score_for_completed(items) +
    Enum.sum(for s <- 5..8, do: score_for_rejected(items, s))
  end

  def score_for_completed(items) do
    task_score = Enum.filter(items, & &1.state == 4 && &1.type == :task) |> Enum.count |> min(4)
    change_score = Enum.filter(items, & &1.state == 4 && &1.type == :change) |> Enum.count |> min(4)
    task_score + change_score
  end

  def score_for_rejected(items, state) do
    task_score = Enum.filter(items, & &1.state == state && &1.type == :task) |> Enum.count
    change_score = Enum.filter(items, & &1.state == state && &1.type == :change) |> Enum.count
    score = min(task_score, 1) + min(change_score, 1)
    bonus = if task_score == 1 && change_score == 1, do: 1, else: 0
    score + bonus
  end

  def recalculate_all_player_options(%Game{players: players, items: items} = game) do
    below_wip_limits = wip_limited_states(game)
    Enum.map(players, &(Player.calculate_player_options(items, &1, below_wip_limits)))
  end

  def get_player(%Game{players: players}, player_id), do: Enum.find(players, &(&1.id == player_id))


  def exec_action(%Game{} = game, act, item_id, player_id) do
    item = Game.get_item(game, item_id)
    player = Game.get_player(game, player_id)

    if player.state == :done do
      Logger.warn("Tried to make a move in :done state")
      game
    else
      {item_, player_} = action(act, item, player)
      update_game(game, item_, player_)
    end
  end

  def action(:unblock, item, player), do: { Item.unblock(item), %{player | state: :done } }
  def action(:reject, item, player), do: { Item.reject(item), %{player | state: :done } }
  def action(:hlp_mv, item, player), do: action(:move, item, player)
  def action(:hlp_unblk, item, player), do: action(:unblock, item, player)
  def action(:start, item, %Player{machine: machine} = player) do
    player_ = case machine do
      :red -> %{player | state: :done }
      :black ->
        case player.past do
          :blocked -> %{player | state: :done, past: nil}
          _        -> %{player | past: :started}
        end
      end
      { Item.start(item, player.id), player_ }
  end
  def action(:block, item, player) do
    player_ =
      case player.past do
        :started -> %{player | state: :done, past: nil}
        _        -> %{player | past: :blocked}
      end
    { Item.block(item, player.id), player_}
  end
  def action(:move, item, player) do
    item_ = Item.move_right(item)
    player_ =
      if Item.complete?(item_) do
        %{player | past: :completed }
      else
        %{player | state: :done }
      end
      {item_, player_}
  end
  def action(act, _, _), do: raise "invalid action: #{inspect act}"

  # WIP Limit Management

  def wip_limited_states(%Game{wip_limits: {:none, _}}), do: @no_wip_limits
  def wip_limited_states(%Game{items: items, wip_limits: {:std, limits}}) do
    new_limits = Map.new(limits, fn {state_id, limit} -> {state_id, state_wip_open?(items, state_id, limit)} end)
    Map.merge(@no_wip_limits, new_limits)
  end
  # conwip stops you starting
  def wip_limited_states(%Game{items: items, wip_limits: {:con, limit}}) do
    c = Enum.map([1,2,3], &item_count_for_state(items, &1)) |> Enum.sum
    cond do
      limit == 0 ->
        Logger.warn("Tried to set 0 conwip")
        @no_wip_limits
      limit > c -> @no_wip_limits
      true -> %{1 => false, 2 => true, 3 => true}
    end
  end

  def state_wip_open?(items, state_id, limit) do
    limit > item_count_for_state(items, state_id)
  end

  def item_count_for_state(items, state_id) do
      Enum.group_by(items, &(&1.state))
        |> Map.get(state_id, [])
        |> Enum.count
  end
end
