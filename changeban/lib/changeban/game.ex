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
  defstruct players: [], max_players: 0, items: [], score: 0, turn: 0

  alias Changeban.{Game, Item, Player}

  def new() do
    %Game{items: (for id <- 0..15, do: Item.new(id)), max_players: (@max_player_id + 1)}
  end

  def add_player(%Game{players: players} = game) do
    new_player_id = player_count(game)
    if new_player_id <= @max_player_id do
      new_player = Player.new(new_player_id)
      {:ok, new_player_id, %{game | players: [new_player | players]}}
    else
      {:error, "Already at max players"}
    end
  end

  def player_count(%Game{players: players}) do
    Enum.count(players)
  end

  def start_game(%Game{turn: turn} = game) do
    cond do
      turn == 0 -> new_turn(game)
      :true -> {:error, "Game already started"}
    end
  end

  def new_turn(%Game{players: players, turn: turn} = game) do
    %{game | players: Enum.map(players, &(%{&1 | machine: Enum.random([:red, :black]), state: :act})),
              turn: turn + 1}
    |> recalculate_state
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
    Enum.map(players, &(calculate_player_options(items, &1)))
  end

  def calculate_player_options(items, %Player{machine: machine, state: state, past: past} = player) do
    if state == :act && past == :completed do
      rejectable_items = for %{id: id} = item <- items, Item.active?(item), do: id
      if Enum.empty?(rejectable_items) do
        %{player | state: :done, options: nil }
      else
        %{player | options: rejectable_items }
      end
    else
        case machine do
          :red -> red_options(items, player)
          :black -> black_options(items, player)
        end
      end
  end

  @doc"""
  Identifies the possible actions for a player on a "red" turn.any()

  Returns:
  %Player{machine: :red, state: :done, :past _, options: nil}
  %Player{machine: :red, state: :act, :past _, ...}

  RED moves
  EITHER:
    EITHER: move ONE of your unblocked items ONE column right
    OR:     unblock ONE of your blocked items
    OR:     start ONE new item (if any remain)

  If you cannot do ANY of these, then HELP someone
  """
  def red_options(_items, %Player{state: :done} = player), do: %{player | options: nil}
  def red_options(items, %Player{id: pid} = player) do
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id
    move = for %{id: id} = item <- items, Item.can_move?(item, pid), do: id
    unblock = for %{id: id} = item <- items, Item.can_unblock?(item, pid), do: id

    if Enum.empty?(start) && Enum.empty?(move) && Enum.empty?(start) do
      help_options(items, player)
    else
      %{player | state: :act, options: [move: move, unblock: unblock, start: start]}
    end
  end

  @doc"""

  Returns either:
  %Player{machine: :black, state: (:act|:done), past:(:blocked|:started), ...}

  BLACK MOVES
  BOTH:
    BLOCK:    block ONE unblocked item, if you own one
    AND START: start ONE new item (if any remain)

  If you cannot START, then HELP someone
  """

  def black_options(_items, %Player{state: :done} = player), do: %{player | options: nil}
  def black_options(items, %Player{id: pid, past: past} = player) do
    block = for %{id: id} = item <- items, Item.can_block?(item, pid), do: id
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id

    case past do
      :blocked -> cond do
          Enum.empty?(start) -> help_options(items, player)
          :true -> %{player | options: [block: [], start: start]}
        end
      :started -> cond do
          Enum.empty?(block) -> %{player | state: :done, options: nil}
          :true -> %{player | options: [block: block, start: []]}
        end
      nil ->
        %{player | state: :act, options: [block: block, start: start]}
    end
  end
  @doc"""
    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    Returns: %Player{}
  """
  def help_options(items, %Player{id: pid} = player) do
    move = for %{id: id} = item <- items, Item.can_help_move?(item, pid), do: id
    unblock = for %{id: id} = item <- items, Item.can_help_unblock?(item, pid), do: id

    if Enum.empty?(move) && Enum.empty?(unblock) do
      %{player | state: :done, options: nil}
    else
      %{player | state: :act, options: [move: move, unblock: unblock]}
    end
  end

  def get_player(%Game{players: players}, player_id), do: Enum.find(players, &(&1.id == player_id))


  def exec_action(%Game{} = game, act, item_id, player_id) do
    item = Game.get_item(game, item_id)
    player = Game.get_player(game, player_id)

    {item_, player_} = action(act, item, player)

    update_game(game, item_, player_)
  end

  def action(:unblock, item, player), do: { Item.unblock(item), %{player | state: :done } }
  def action(:reject, item, player), do: { Item.reject(item), %{player | state: :done } }
  def action(:start, item, %Player{machine: machine} = player) do
    item_ = Item.start(item, player.id)
    player_ = case machine do
      :red -> %{player | state: :done }
      :black -> %{player | past: :started }
    end
    { item_, player_ }
  end
  def action(:block, item, player), do: { Item.block(item, player.id), %{player | past: :blocked } }
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
