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
  defstruct players: [], items: [], score: 0, turn: 0

  alias Changeban.{Game, Item, Player}

  def new() do
    %Game{items: (for id <- 0..15, do: Item.new(id))}
  end

  def add_player(%Game{players: players} = game) do
    new_player_id = Enum.count(players)
    if new_player_id <= @max_player_id do
      new_player = Player.new(new_player_id)
      %{game | players: [new_player | players]}
    else
      raise "Already at max players"
    end
  end

  def player_count(%Game{players: players}) do
    Enum.count(players)
  end

  def new_turn(%Game{players: players} = game) do
      %{game | players: Enum.map(players, &(%{&1 | machine: Enum.random([:red, :black]), state: :new}))}
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

      Game.recalculate_state(%{game | items: items_, players: players_})
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

  def recalculate_state(game) do
    score = calculate_score(game)
    players = recalculate_all_player_options(game)

    # turn_completed = Enum.find(players, &(&1.state != :done))

    game
    |> Map.put(:score, score)
    |> Map.put(:players, players)
  end

  def recalculate_all_player_options(%Game{players: players} = game) do

    # TODO Players could be :red, :black, :done, :helping
    Enum.map(players, &(calculate_player_options(game, &1)))
  end

  def calculate_player_options(%Game{items: items}, %Player{machine: machine, state: state} = player) do
    if state == :reject do
      rejectable_items = for %{id: id} = item <- items, Item.active?(item), do: id
      %{player | options: rejectable_items }
    else
      {machine_, state_, options} =
        case machine do
          :red -> red_options(items, player)
          :black -> black_options(items, player)
          :help -> help_options(items, player)
        end

      %{player | machine: machine_, state: state_, options: options }
      end
  end

  @doc"""
  Identifies teh possible actions for a player on a "red" turn.any()

  Returns either:
    {:act, [move: move, unblock: unblock, start: start]}
    {:help, [move: move, :unblock unblock]}

  RED moves
  EITHER:
    EITHER: move ONE of your unblocked items ONE column right
    OR:     unblock ONE of your blocked items
    OR:     start ONE new item (if any remain)

  If you cannot do ANY of these, then HELP someone
  """
  def red_options(items, %Player{id: pid} = player) do
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id
    move = for %{id: id} = item <- items, Item.can_move?(item, pid), do: id
    unblock = for %{id: id} = item <- items, Item.can_unblock?(item, pid), do: id

    if Enum.empty?(start) && Enum.empty?(move) && Enum.empty?(start) do
      help_options(items, player)
    else
      {:red, :act, [move: move, unblock: unblock, start: start]}
    end
  end

  @doc"""

  Returns either:
  {:act, [block: block, start: start]}
  {:help, [move: move, :unblock unblock]}

  BLACK MOVES
  BOTH:
    BLOCK:    block ONE unblocked item, if you own one
    AND START: start ONE new item (if any remain)

  If you cannot START, then HELP someone
  """

  def black_options(items, %Player{id: pid, state: state} = player) do
    block = for %{id: id} = item <- items, Item.can_block?(item, pid), do: id
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id

    case state do
      :new -> cond do
          Enum.empty?(start) && Enum.empty?(block) -> help_options(items, player)
          Enum.empty?(block) && ! Enum.empty?(start) -> {:black, :start, [block: block, start: start]}
          Enum.empty?(start) && ! Enum.empty?(block) -> {:black, :block, [block: block, start: start]}
        end
      :done -> {:black, :done, [block: [], start: []]}
    end
  end
  @doc"""
    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    Returns:
    {:help, [move: move, :unblock unblock]}
  """
  def help_options(items, %Player{id: pid}) do
    move = for %{id: id} = item <- items, Item.can_help_move?(item, pid), do: id
    unblock = for %{id: id} = item <- items, Item.can_help_unblock?(item, pid), do: id

    if Enum.empty?(move) && Enum.empty?(unblock) do
      {:help, :done, [move: move, unblock: unblock]}
    else
      {:help, :act, [move: move, unblock: unblock]}
    end
  end

  def exec_action(%{players: players} = game, act, item_id, player_id) do
    item = Game.get_item(game, item_id)
    player = Enum.find(players, &(&1.id == player_id))

    {item_, player_} = action(act, item, player)

    update_game(game, item_, player_)
  end

  def action(:start, item, player), do: { Item.start(item, player.id), %{player | state: :done } }
  def action(:block, item, player), do: { Item.block(item, player.id), %{player | state: :done } }
  def action(:unblock, item, player), do: { Item.unblock(item), %{player | state: :done } }
  def action(:reject, item, player), do: { Item.reject(item), %{player | state: :done } }
  def action(:move, item, player) do
    item_ = Item.move_right(item)
    player_ =
      if Item.complete?(item_) do
        %{player | state: :reject }
      else
        %{player | state: :done }
      end
    {item_, player_}
  end
  def action(act, _, _), do: raise "invalid action: #{inspect act}"
end
