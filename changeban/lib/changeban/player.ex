defmodule Changeban.Player do
  @moduledoc """
    Tracks players information and turn state

    :id must be an integer from 0-4 for an active player
    :machine must be :red, :black or :help
    :state must be :new, :act, :reject, :done

    RED moves
    EITHER:
      EITHER: move ONE of your unblocked items ONE column right
      OR:     unblock ONE of your blocked items
      OR:     start ONE new item (if any remain)

    If you cannot do ANY of these, then HELP someone

    :red state machine
    before   act       after      + found available acts
    ------   ------    -------    -------------------------
    -        new_turn  :act       self n start|move|unblock
    -        new_turn  ->help     self 0 start|move|unblock
    :act     *calc     :act       self n start|move|unblock
    :act     *calc     ->help     self 0 start|move|unblock
    :act     ! accept  :done      -
    :act     accept    :reject    all n rejectable
    :act     accept    :done      all 0 rejectable
    :done    *calc     :done      -

    BLACK MOVES
    BOTH:
      BLOCK:    block ONE unblocked item, if you own one
      AND START: start ONE new item (if any remain)

    If you cannot START, then HELP someone

    :black state machine
    before   act       after      + found available acts
    ------   ------    -------    --------------------------------------
    :new     *calc     ->help     0 starts, 0 blocks
    :new     *calc     :start     n starts, 0 blocks
    :new     *calc     :block     0 starts, n blocks
    :new     *calc     :both      n starts, n blocks
    :start   start     :done      -
    :block   block     :help      n start
    :block   block     :done      other 0 start|move|unblock   game is probably over
    :done    *calc     :done      -


    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    :help state machine
    before   act       after      + found available acts
    ------   ------    -------    --------------------------------------
    -        ->help    :act       other n start|move|unblock
    -        ->help    :done      other 0 start|move|unblock   game is probably over
    :act     accept    :reject    n rejectable (all players)
    :act     ! accept  :done      -
    :act     accept    :done      0 rejectable (all player)    game is probably over
    :help    *calc     :help      other n start|move|unblock
    :help    *calc     :done      other 0 start|move|unblock   game is probably over
    :done    *calc     :done      -

    at start of turn is calculated as :red or :black
    if :red, after moving state goes to done (unless move was accept)
    if :black, both block and start

  """
  alias Changeban.{Player, Item}

  defstruct id: nil, machine: nil, state: nil, past: nil, options: nil

  def new(id) do
     %Player{id: id}
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
end
