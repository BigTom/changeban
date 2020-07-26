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
    before  after    act       + found available acts
    ------  -------  ------    --------------------------------------
    :new    :act     *calc     self n start|move|unblock
    :new    ->help   *calc     self 0 start|move|unblock
    :act    :act     *calc     self n start|move|unblock    recalcs after another player moves
    :act    ->help   *calc     self 0 start|move|unblock    recalcs after another player moves
    :act    :done    ! accept  -
    :act    :reject  accept    all n rejectable
    :act    :done    accept    all 0 rejectable             game is probably over
    :done   :done    *calc     -

    BLACK MOVES
    BOTH:
      BLOCK:    block ONE unblocked item, if you own one
      AND START: start ONE new item (if any remain)

    If you cannot START, then HELP someone

    :black state machine
    before  after    act       + found available acts
    ------  -------  ------    --------------------------------------
    :new    :start   *calc     n starts, 0 blocks
    :new    :block   *calc     0 starts, n blocks
    :new    ->help   *calc     0 starts, 0 blocks
    :start  :done    start     -
    :block  :help    block     other n start|move|unblock
    :block  :done    block     other 0 start|move|unblock   game is probably over
    :done   :done    *calc     -


    If you cannot MOVE, HELP someone!
    Advance or unblock ONE item from another player

    :help state machine
    before  after    act       + found available acts
    ------  -------  ------    --------------------------------------
    -       :act     ->help    other n start|move|unblock
    -       :done    ->help    other 0 start|move|unblock   game is probably over
    :act    :reject  accept    n rejectable (all players)
    :act    :done    ! accept  -
    :act    :done    accept    0 rejectable (all player)    game is probably over
    :help   :help    *calc     other n start|move|unblock
    :help   :done    *calc     other 0 start|move|unblock   game is probably over
    :done   :done    *calc     -

    at start of turn is calculated as :red or :black
    if :red, after moving state goes to done (unless move was accept)
    if :black, both block and start

  """
  alias Changeban.Player

  defstruct id: nil, machine: nil, state: nil, options: nil

  def new(id) do
     %Player{id: id}
  end
end
