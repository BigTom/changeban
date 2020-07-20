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
  defstruct players: [], items: []

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

  def start_item(%Game{} = game, id, player) do
    started_item = get_item(game, id) |> Item.start(player)
    change_item(game, started_item)
  end

  def get_item(%Game{items: items}, id) do
    items |> Enum.find(& ( &1.id == id))
  end

  def change_item(%Game{items: items} = game, %Item{} = new_item) do
    new_items =
      items
      |> Enum.filter(& ( &1.id != new_item.id))
      |> List.insert_at(0, new_item)
      |> Enum.sort_by(& &1.id)
    %{game | items: new_items}
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
"""
  def red_options(%Game{items: items}, player) do
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id
    move = for %{id: id} = item <- items, Item.can_move?(item, player), do: id
    unblock = for %{id: id} = item <- items, Item.can_unblock?(item, player), do: id

    if Enum.empty?(start) && Enum.empty?(move) && Enum.empty?(start) do
      help_options(items, player)
    else
      {:act, [move: move, unblock: unblock, start: start]}
    end
  end

  @doc"""

  Returns either:
  {:act, [block: block, start: start]}
  {:help, [move: move, :unblock unblock]}

  YOU MUST BOTH:
    BLOCK:    block ONE unblocked item, if you own one
    AND START: start ONE new item (if any remain)
  """

  def black_options(%Game{items: items}, player) do
    block = for %{id: id} = item <- items, Item.can_block?(item, player), do: id
    start = for %{id: id} = item <- items, Item.can_start?(item), do: id

    if Enum.empty?(start) && Enum.empty?(block)do
      help_options(items, player)
    else
      {:act, [block: block, start: start]}
    end
  end
  @doc"""
    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    Returns:
    {:help, [move: move, :unblock unblock]}
  """
  def help_options(items, player) do
    move = for %{id: id} = item <- items, Item.can_help_move?(item, player), do: id
    unblock = for %{id: id} = item <- items, Item.can_help_unblock?(item, player), do: id
    {:help, [move: move, unblock: unblock]}
  end

  @doc"""
    This changes an identified item based on the function provided and the player_id.
    The game is then updated with the new item replacing its old version

    This is a DRY change for the :handle_move :act, :help & :block methods in GameServer
  """
  def exec_action(game, fun, item_id, player_id) do
    new_item =
      Game.get_item(game, item_id)
      |> fun.(player_id)
    Game.change_item(game, new_item)
  end

end
