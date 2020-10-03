defmodule ChangebanItemTest do
  use ExUnit.Case
  doctest Changeban.Item

  alias Changeban.Item

  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  test "New item" do
    assert %Item{blocked: false, id: 3, owner: nil, state: 0, type: :change} == Item.new(3)
    assert %Item{blocked: false, id: 4, owner: nil, state: 0, type: :task} == Item.new(4)
  end

  test "Start an item" do
    started = Item.new(3) |> Item.start(1)
    assert %Item{blocked: false, id: 3, owner: 1, state: 1, type: :change} == started
  end
  test "Start a started item" do
    started = Item.new(3) |> Item.start(1)
    assert_raise RuntimeError, "Trying to start a started item", fn -> Item.start(started, 2) end
  end
  test "basic move_right test" do
    item = Item.new(1) |> Item.start(0)
    assert 2 == (Item.move_right(item)).state
  end
  test "will move_right to complete" do
    item =
      Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right
    assert 4 == (Item.move_right(item)).state
  end
  test "won't move completed items move_right test" do
    item =
      Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right
    assert_raise RuntimeError, "Trying to move a completed item", fn -> (Item.move_right(item)) end
  end

  test "basic reject test" do
    item = Item.new(1)
    assert 5 == (Item.reject(item)).state
  end
  test "latest chance to reject test" do
    item = Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right
    assert 8 == (Item.reject(item)).state
  end
  test "cannot reject completed item test" do
    item = Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right
    assert_raise RuntimeError, "Trying to reject a completed item", fn -> (Item.reject(item)) end
  end

  test "basic block test" do
    item = Item.new(1) |> Item.start(0)
    assert (Item.block(item, 0)).blocked
  end

  test "block failure modes test" do
    item = Item.new(1)

    assert_raise RuntimeError, "Player 0 cannot block %Changeban.Item{blocked: false, id: 1, owner: nil, state: 0, type: :change} ", fn -> Item.block(item, 0) end
    item = Item.new(1) |> Item.start(0
    ) |> Item.move_right |> Item.move_right |> Item.move_right
    assert_raise RuntimeError, "Player 0 cannot block %Changeban.Item{blocked: false, id: 1, owner: 0, state: 4, type: :change} ", fn -> Item.block(item, 0) end
    item = Item.new(1) |> Item.reject

    assert_raise RuntimeError, "Player 0 cannot block %Changeban.Item{blocked: false, id: 1, owner: nil, state: 5, type: :change} ", fn -> Item.block(item, 0) end
  end

  test "basic unblock test" do
    item = Item.new(1) |> Item.start(0) |> Item.block(0)
    refute (Item.unblock(item)).blocked
  end

  test "try to unblock an unblocked item test" do
    item = Item.new(1) |> Item.start(0)
    assert_raise FunctionClauseError, ~r/^no function clause matching/, fn -> Item.unblock(item) end
  end

  test "not_started? test" do
    assert Item.in_agree_urgency?(Item.new(1))
    refute Item.in_agree_urgency?(Item.new(1) |> Item.start(0))
    refute Item.in_agree_urgency?(Item.new(1) |> Item.start(0) |> Item.reject())
    refute Item.in_agree_urgency?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
  end
  test "started? test" do
    assert Item.in_progress?(Item.new(1) |> Item.start(0))
    refute Item.in_progress?(Item.new(1))
    refute Item.in_progress?(Item.new(1) |> Item.start(0) |> Item.reject())
    refute Item.in_progress?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
  end
  test "active? test" do
    assert Item.active?(Item.new(1))
    assert Item.active?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right)
    refute Item.active?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
  end
  test "blocked? test" do
    assert Item.blocked?(Item.new(1) |> Item.start(0) |> Item.block(0))
    refute Item.blocked?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
  end
  test "finished? test" do
    assert Item.finished?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
    refute Item.finished?(Item.new(1))
    refute Item.finished?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right)
  end
  test "rejected? test" do
    assert Item.rejected?(Item.new(1) |> Item.reject)
    refute Item.rejected?(Item.new(1))
    refute Item.rejected?(Item.new(1) |> Item.start(0) |> Item.move_right |> Item.move_right |> Item.move_right)
  end
  test "can_start? test" do
    assert Item.can_start?(new_item(), @no_wip_limits), "agree urgency items count"
    refute Item.can_start?(in_progress_item(0), @no_wip_limits), "My in_progress items don't count"
    refute Item.can_start?(in_progress_item(1), @no_wip_limits), "Other player's items don't count"
    refute Item.can_start?(completed_item(0), @no_wip_limits), "Completed items don't count"
    refute Item.can_start?(rejected_item(0), @no_wip_limits), "Rejected items don't count"
    refute Item.can_start?(blocked_item(0), @no_wip_limits), "Blocked items don't count"
    refute Item.can_start?(new_item(), %{1 => false, 2 => true, 3 => true}), "Blocked by WIP limit"
  end
  test "can_move? test" do
    assert Item.can_move?(in_progress_item(0), 0, @no_wip_limits), "My in_progress items count"
    refute Item.can_move?(new_item(), 0, @no_wip_limits), "agree urgency items don't count"
    refute Item.can_move?(in_progress_item(1), 0, @no_wip_limits), "Other player's items don't count"
    refute Item.can_move?(completed_item(0), 0, @no_wip_limits), "Completed items don't count"
    refute Item.can_move?(rejected_item(0), 0, @no_wip_limits), "Rejected items don't count"
    refute Item.can_move?(blocked_item(0), 0, @no_wip_limits), "Blocked items don't count"
    refute Item.can_move?(in_progress_item(0), 0, %{1 => false, 2 => true, 3 => false}), "Blocked by WIP limit"
  end
  test "can_block? test" do
    assert Item.can_block?(in_progress_item(0), 0), "My in_progress items count"
    refute Item.can_block?(new_item(), 0), "agree urgency items don't count"
    refute Item.can_block?(in_progress_item(1), 0), "Other player's items don't count"
    refute Item.can_block?(completed_item(0), 0), "Completed items don't count"
    refute Item.can_block?(rejected_item(0), 0), "Rejected items don't count"
    refute Item.can_block?(blocked_item(0), 0), "Blocked items don't count"
  end
  test "can_unblock? test" do
    assert Item.can_unblock?(blocked_item(0), 0), "My blocked items count"
    refute Item.can_unblock?(in_progress_item(0), 0), "My items don't count"
    refute Item.can_unblock?(new_item(), 0), "agree urgency items don't count"
    refute Item.can_unblock?(blocked_item(1), 0), "Other player's items don't count"
    refute Item.can_unblock?(completed_item(0), 0), "Completed items don't count"
    refute Item.can_unblock?(rejected_item(0), 0), "Rejected items don't count"
  end
  test "can_help_move? test" do
    assert Item.can_help_move?(in_progress_item(1), 0, @no_wip_limits), "Other player's items count"
    refute Item.can_help_move?(in_progress_item(1), 1, @no_wip_limits), "My items don't count"
    refute Item.can_help_move?(blocked_item(1), 0, @no_wip_limits), "Blocked items don't count"
    refute Item.can_help_move?(new_item(), 0, @no_wip_limits), "Not started items don't count"
    refute Item.can_help_move?(completed_item(1), 0, @no_wip_limits), "Completed items don't count"
    refute Item.can_help_move?(rejected_item(1), 0, @no_wip_limits), "Rejected items don't count"
    refute Item.can_help_move?(in_progress_item(1), 0, %{1 => false, 2 => true, 3 => false}), "Blocked by WIP limit"
  end
  test "can_help_unblock? test" do
    assert Item.can_help_unblock?(blocked_item(1), 0), "Other player's blocked items count"
    refute Item.can_help_unblock?(blocked_item(1), 1), "My items don't count"
    refute Item.can_help_unblock?(in_progress_item(1), 0), "Other player's unblocked items don't count"
    refute Item.can_help_unblock?(new_item(), 0), "Not started items don't count"
    refute Item.can_help_unblock?(completed_item(1), 0), "Completed items don't count"
    refute Item.can_help_unblock?(rejected_item(1), 0), "Rejected items don't count"
  end

  def new_item(), do: Item.new(7)
  def in_progress_item(player), do: Item.new(7) |> Item.start(player) |> Item.move_right
  def blocked_item(player), do: Item.new(7) |> Item.start(player) |> Item.block(player)
  def completed_item(player) do
    Item.new(7) |> Item.start(player) |> Item.move_right |> Item.move_right |> Item.move_right
  end
  def rejected_item(_player) do
    Item.new(7) |> Item.reject
  end
end
