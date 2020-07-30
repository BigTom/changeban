defmodule Changeban.Item do
  @moduledoc """
  Manages the item state.

  An item has:
    type     - atom    - it can be a :task, or a :change
    id       - integer - unique task id
    state   - integer - current active state of task.  Values are:
                          0 AU  Agree Urgency
                          1 NC  Negotiate Change
                          2 VA  Validate Adoption
                          3 VP  Verify Performance
                          4 C   Complete
                          5 RAU Rejected - Agree Urgency
                          6 RNC Rejected - Negotiate Change
                          7 RVA Rejected - Validate Adoption
                          8 RVP Rejected - Verify Performance

    owner    - integer - owner id of task.  nil for items in Agree Urgency state
    blocked  - boolean - true if the item is currently blocked

  future - track history of game
    moves        - the list of :red and :black moves
    turn         - current turn number
    blocked list - history blocked status
  """
  defstruct type: :task, id: 0, state: 0, owner: nil, blocked: false

  alias Changeban.Item

  def new(id) do
    if (rem(id, 2) == 0) do
      %Item{type: :task, id: id}
    else
      %Item{type: :change, id: id}
    end
  end

  def block(%Item{blocked: false} = item, player_id) do
    if in_progress?(item) && item.owner == player_id do
      %{item | blocked: true }
    else
      raise "Player #{player_id} cannot block #{inspect(item)} "
    end
  end

  def unblock(%Item{blocked: true} = item), do: %{item | blocked: false }
  def unblock(item, _player_id), do: item

  def in_agree_urgency?(%Item{state: state}), do: state == 0
  def in_progress?(%Item{state: state}), do: 0 < state && state < 4
  def complete?(%Item{state: state}), do: state == 4
  def rejected?(%Item{state: state}), do: 4 < state && state <= 8
  def blocked?(%Item{blocked: blocked}), do: blocked

  def active?(item), do: in_agree_urgency?(item) || in_progress?(item)
  def finished?(item), do: complete?(item) || rejected?(item)

  def start(%Item{state: 0} = item, owner), do: %{item | state: 1, owner: owner}
  def start(%Item{}, _), do: raise "Trying to start a started item"

  def move_right(%Item{} = item) do
    if active?(item) do
      %{item | state: item.state + 1}
    else
      raise "Trying to move a completed item"
    end
  end

  def reject(%Item{state: state} = item) do
    if Item.active?(item) do
      %{item | state: state + 5, blocked: false}
    else
      raise "Trying to reject a completed item"
    end
  end

  def can_start?(%Item{} = item) do
    Item.in_agree_urgency?(item)
  end
  def can_move?(%Item{owner: owner, blocked: blocked} = item, player) do
    answer = Item.in_progress?(item) && owner == player && ! blocked
    answer
  end
  def can_unblock?(%Item{owner: owner, blocked: blocked} = item, player) do
    Item.in_progress?(item) && owner == player && blocked
  end
  def can_block?(item, player) do
    can_move?(item, player)
  end
  def can_help_unblock?(%Item{owner: owner, blocked: blocked} = item, player_id) do
    Item.in_progress?(item) && owner != player_id && blocked
  end
  def can_help_move?(%Item{owner: owner, blocked: blocked} = item, player_id) do
    Item.in_progress?(item) && owner != player_id && ! blocked
  end
end
