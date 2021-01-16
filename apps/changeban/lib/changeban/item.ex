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
    day         - current day number
    blocked list - history blocked status
  """

  alias Changeban.{Item, ItemHistory}

  defstruct type: :task, id: 0, state: 0, owner: nil, blocked: false, moved: 0, history: %ItemHistory{}

  def new(id) do
    if (rem(id, 2) == 0) do
      %Item{type: :task, id: id}
    else
      %Item{type: :change, id: id}
    end
  end

  def in_agree_urgency?(%Item{state: state}), do: state == 0
  def in_progress?(%Item{state: state}), do: 0 < state && state < 4
  def complete?(%Item{state: state}), do: state == 4
  def rejected?(%Item{state: state}), do: 4 < state && state <= 8
  def blocked?(%Item{blocked: blocked}), do: blocked

  def active?(item), do: in_agree_urgency?(item) || in_progress?(item)
  def finished?(item), do: complete?(item) || rejected?(item)

  def start(%Item{state: 0, history: history} = item, owner, day) do
    %{item | moved: day, state: 1, owner: owner, history: ItemHistory.start(history, day)}
  end

  def start(%Item{}, _owner, _turn), do: raise "Trying to start a started item"

  def move_right(%Item{history: history} = item, day) do
    new_state = item.state + 1
    if active?(item) do
      %{item | state: new_state, moved: day, history: ItemHistory.move(history, new_state, day)}
    else
      raise "Trying to move a completed item"
    end
  end

  def help_move_right(item, day) do
    move_right(item, day)
    |> help(day)
  end

  def reject(%Item{state: state, history: history} = item, day) do
    new_state = state + 5
    if Item.active?(item) do
      %{item | moved: day, state: new_state, history: ItemHistory.reject(history, new_state, day)}
    else
      raise "Trying to reject a completed item"
    end
  end

  def block(%Item{blocked: false, history: history} = item, player_id, day) do
    if in_progress?(item) && item.owner == player_id do
      %{item | blocked: true, history: ItemHistory.block(history, day) }
    else
      raise "Player #{player_id} cannot block #{inspect(item)} "
    end
  end

  def unblock(%Item{blocked: true, history: history} = item, day) do
    %{item | blocked: false, history: ItemHistory.unblock(history, day) }
  end

  def help_unblock(item, day) do
    unblock(item, day)
    |> help(day)
  end

  def help(%Item{history: history} = item, day) do
    %{item | history: ItemHistory.help(history, day) }
  end

  def owned?(%Item{owner: owner_id}, player_id), do: owner_id == player_id

  def is_next_state_wip_limited?(state, is_wip_open) do
    Map.get(is_wip_open, state + 1, true)
  end

  def can_start?(%Item{state: state} = item, is_wip_open) do
    Item.in_agree_urgency?(item) && is_next_state_wip_limited?(state, is_wip_open)
  end
  def can_move?(%Item{blocked: blocked, state: state} = item, player, is_wip_open) do
    Item.in_progress?(item) && owned?(item, player) && ! blocked && is_next_state_wip_limited?(state, is_wip_open)
  end
  def can_help_move?(%Item{owner: owner, blocked: blocked, state: state} = item, player_id, is_wip_open) do
    Item.in_progress?(item) && owner != player_id && ! blocked && is_next_state_wip_limited?(state, is_wip_open)
  end

  def can_unblock?(%Item{blocked: blocked} = item, player) do
    Item.in_progress?(item) && owned?(item, player) && blocked
  end
  def can_block?(%Item{blocked: blocked} = item, player) do
    Item.in_progress?(item) && owned?(item, player) && ! blocked
  end
  def can_help_unblock?(%Item{owner: owner, blocked: blocked} = item, player_id) do
    Item.in_progress?(item) && owner != player_id && blocked
  end

  # STATS

  def ages(items) do
    Enum.map(items, & &1.history)
    |> Enum.filter(&(!is_nil(&1.done)))
    |> Enum.map(&%{x: &1.done, y: ItemHistory.age(&1, 0)})
  end

  def efficency(items) do
    sum = Enum.map(items, fn i -> ItemHistory.efficency(i.history) end) |> Enum.sum()
    count = Enum.count(items)
    sum / count
  end

  def block_count(items) do
    Enum.map(items, fn i -> ItemHistory.block_count(i.history) end) |> Enum.sum()
  end

  def help_count(items) do
    Enum.map(items, fn i -> ItemHistory.help_count(i.history) end) |> Enum.sum()
  end

  def median_age(items) do
    ages =
      Enum.map(items, & &1.history)
      |> Enum.filter(&(!is_nil(&1.done)))
      |> Enum.map(&ItemHistory.age(&1, 0))
      |> Enum.sort

    if Enum.empty?(ages) do
      0
    else
      len = Enum.count(ages)
      mid = div(len,2)
      case rem(len, 2) do
        1 -> Enum.at(ages, mid)
        0 -> (Enum.at(ages, mid) + Enum.at(ages, mid - 1)) / 2
      end
    end
  end
end
