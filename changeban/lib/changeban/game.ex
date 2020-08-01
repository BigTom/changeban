defmodule Changeban.Game do
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

  @enforce_keys [:items]
  defstruct players: [], max_players: 0, items: [], score: 0, turn: 0, state: :setup

  alias Changeban.{Game, Item, Player}

  def new() do
    %Game{items: initial_items(), max_players: (@max_player_id + 1)}
  end

  def new_short_game_for_testing() do
    %Game{items: (for id <- 0..3, do: Item.new(id)), max_players: (@max_player_id + 1)}
  end

  def initial_items() do
    for id <- 0..15, do: Item.new(id)
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

  def player_count(%Game{players: players}) do
    Enum.count(players)
  end

  def start_game(%Game{turn: turn, state: state} = game) do
      cond do
        turn == 0 && state == :setup -> %{new_turn(game) | state: :running}
        :true -> {:error, "Game already started"}
      end
  end

  def new_turn(%Game{state: :done} = game), do: game
  def new_turn(%Game{players: players, turn: turn} = game) do
    IO.puts("In new_turn ")
    cond do
      game_over?(game) -> %{game | state: :done}
      all_blocked?(game) ->
        %{game | players: Enum.map(players, &(%{&1 | machine: :red, state: :act, past: nil})), turn: turn + 1}
            |> recalculate_state
      true ->
        %{game | players: Enum.map(players, &(%{&1 | machine: red_or_black(), state: :act, past: nil})), turn: turn + 1}
            |> recalculate_state
    end
  end

  def red_or_black() do
    Enum.random([:red, :black])
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

  def update_game(%Game{items: items, players: players} = game, %Item{} = item_, %Player{} = player_) do
    items_ =
      items
      |> Enum.filter(& ( &1.id != item_.id))    # Take out existing version
      |> List.insert_at(0, item_)               # insert new version
      |> Enum.sort_by(& &1.id)                  # make sure the order is maintained

    players_ =
      players
      |> Enum.filter(& ( &1.id != player_.id))  # Take out existing version
      |> List.insert_at(0, player_)             # insert new version
      |> Enum.sort_by(& &1.id)                  # make sure the order is maintained

    recalculate_state(%{game | items: items_, players: players_})
  end

  def recalculate_state(game) do
    # IO.puts("In recalculate_state #{inspect game}")
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

  def recalculate_all_player_options(%Game{players: players, items: items}) do
    Enum.map(players, &(Player.calculate_player_options(items, &1)))
  end

  def get_player(%Game{players: players}, player_id), do: Enum.find(players, &(&1.id == player_id))


  def exec_action(%Game{} = game, act, item_id, player_id) do
    item = Game.get_item(game, item_id)
    player = Game.get_player(game, player_id)

    if player.state == :done, do: raise "OOPS"
    {item_, player_} = action(act, item, player)

    update_game(game, item_, player_)
  end

  def action(:unblock, item, player), do: { Item.unblock(item), %{player | state: :done } }
  def action(:reject, item, player), do: { Item.reject(item), %{player | state: :done } }
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
    IO.puts("blocking #{inspect player_}")
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
end
