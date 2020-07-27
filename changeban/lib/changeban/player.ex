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
  alias Changeban.Player

  defstruct id: nil, machine: nil, state: nil, past: nil, options: nil

  def new(id) do
     %Player{id: id}
  end
end
