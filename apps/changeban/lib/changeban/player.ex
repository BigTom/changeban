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

  defstruct id: nil, machine: nil, state: nil, past: nil, options: Map.new, initials: nil, name: nil

  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  def new(id, initials) do
     %Player{id: id, options: empty_options(), initials: initials}
  end

  def empty_options(), do: %{start: [], move: [], unblock: [], block: [], hlp_mv: [], hlp_unblk: [], reject: []}

  def calculate_player_options(_items, %Player{state: :done} = player, _is_wip_open), do: %{player | options: Player.empty_options()}
  def calculate_player_options(items, %Player{machine: machine, state: state, past: past} = player, is_wip_open) do
    player_ = %{player | options: empty_options()}
    if (state == :act || state == :help) && past == :completed do
      rejectable = for %{id: id} = item <- items, Item.active?(item), do: id
      if Enum.empty?(rejectable) do
        %{player_ | state: :done, past: nil }
      else
        options_ = %{Player.empty_options() | reject: rejectable }
        %{player_ | options: options_ }
      end
    else
      case machine do
        :red -> red_options(items, player_, is_wip_open)
        :black -> black_options(items, player_, is_wip_open)
      end
    end
  end

  @doc"""
  Identifies the possible actions for a player on a "red" turn.any()

  Returns:
  %Player{machine: :red, state: :done, :past _, options: Map.new}
  %Player{machine: :red, state: :act, :past _, ...}

  RED moves
  EITHER:
    EITHER: move ONE of your unblocked items ONE column right
    OR:     unblock ONE of your blocked items
    OR:     start ONE new item (if any remain)

  If you cannot do ANY of these, then HELP someone
  """
  def red_options(items, %Player{id: pid} = player, is_wip_open) do
    start = for %{id: id} = item <- items, Item.can_start?(item, is_wip_open), do: id
    move = for %{id: id} = item <- items, Item.can_move?(item, pid, is_wip_open), do: id
    unblock = for %{id: id} = item <- items, Item.can_unblock?(item, pid), do: id
    if Enum.empty?(start) && Enum.empty?(move) && Enum.empty?(unblock) do
      help_options(items, player, @no_wip_limits)
    else
      %{player | state: :act, options: %{Player.empty_options() | move: move, unblock: unblock, start: start}}
    end
  end

  @doc"""

  Returns either:
  %Player{machine: :black, state: (:act|:done), past:(:blocked|:started), ...}

  BLACK MOVES
  BOTH:
    BLOCK:     block ONE unblocked item, if you own one
    AND START: start ONE new item (if any remain)
    (Note: if there is nothing to block you just start)
  If you cannot START, then HELP someone
  """

  def black_options(items, %Player{id: pid, past: past} = player, is_wip_open) do
    block = for %{id: id} = item <- items, Item.can_block?(item, pid), do: id
    start = for %{id: id} = item <- items, Item.can_start?(item, is_wip_open), do: id

    case past do
      :blocked -> cond do
          Enum.empty?(start) -> help_options(items, player, @no_wip_limits)
          :true -> %{player | state: :act, options: %{player.options | start: start}}
        end
      :started ->
        %{player | state: :done, options: Player.empty_options()}
      nil -> cond do
          Enum.empty?(block) && Enum.empty?(start) -> help_options(items, player, @no_wip_limits)
          Enum.empty?(block) -> %{player | state: :act, options: %{player.options | start: start}}
          :true -> %{player | state: :act, options: %{player.options | block: block}}
        end
    end
  end

  @doc"""
    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    Returns: %Player{}
  """
  def help_options(items, %Player{id: pid} = player, is_wip_open) do
    hlp_mv = for %{id: id} = item <- items, Item.can_help_move?(item, pid, is_wip_open), do: id
    hlp_unblk = for %{id: id} = item <- items, Item.can_help_unblock?(item, pid), do: id

    if Enum.empty?(hlp_mv) && Enum.empty?(hlp_unblk) do
      %{player | state: :done, options: Player.empty_options()}
    else
      options_ = %{player.options | hlp_mv: hlp_mv, hlp_unblk: hlp_unblk}
      %{player | state: :help, options: options_}
    end
  end
end
