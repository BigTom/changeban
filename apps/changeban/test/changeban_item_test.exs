defmodule ChangebanItemTest do
  use ExUnit.Case
  doctest Changeban.Item

  alias Changeban.Item

  @no_wip_limits %{1 => true, 2 => true, 3 => true}
  @turn 0
  @owner_0 0
  @owner_1 0
  @item_id 1

  test "New item" do
    assert %Item{blocked: false, id: 3, owner: nil, state: 0, type: :change} == Item.new(3)
    assert %Item{blocked: false, id: 4, owner: nil, state: 0, type: :task} == Item.new(4)
  end

  test "Start an item" do
    started = Item.new(@item_id) |> Item.start(@owner_0, @turn)

    assert %Item{blocked: false, id: @item_id, owner: @owner_0, state: 1} = started
  end

  test "Start a started item" do
    started = Item.new(@item_id) |> Item.start(@owner_0, @turn)

    assert_raise RuntimeError, "Trying to start a started item", fn ->
      Item.start(started, @owner_1, @turn)
    end
  end

  test "basic move_right test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @turn)
    assert 2 == Item.move_right(item, @turn).state
  end

  test "will move_right to complete" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)

    assert 4 == Item.move_right(item, @turn).state
  end

  test "won't move completed items move_right test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)

    assert_raise RuntimeError, "Trying to move a completed item", fn ->
      Item.move_right(item, @turn)
    end
  end

  test "basic reject test" do
    item = Item.new(@item_id)
    assert 5 == Item.reject(item, @turn).state
  end

  test "latest chance to reject test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)

    assert 8 == Item.reject(item, @turn).state
  end

  test "cannot reject completed item test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)

    assert_raise RuntimeError, "Trying to reject a completed item", fn ->
      Item.reject(item, @turn)
    end
  end

  test "basic block test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @turn)
    assert Item.block(item, @owner_0, @turn).blocked
  end

  test "block failure cannot block unstarted item test" do
    test_id = 7
    item = Item.new(test_id)

    assert_raise RuntimeError,
                 ~r/^Player 0 cannot block %Changeban.Item/,
                 fn -> Item.block(item, @owner_0, @turn) end
  end

  test "block failure cannot block completed item test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)
      |> Item.move_right(@turn)

    assert_raise UndefinedFunctionError,
                 "function Changeban.Item.block/2 is undefined or private",
                 fn -> Item.block(item, 0) end
  end

  test "block failure cannot block rejected item test" do
    item =
      Item.new(@item_id)
      |> Item.reject(@turn)

    assert_raise UndefinedFunctionError,
                 "function Changeban.Item.block/2 is undefined or private",
                 fn -> Item.block(item, 0) end
  end

  test "basic unblock test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @turn)
      |> Item.block(@owner_0, @turn)

    refute Item.unblock(item, @turn).blocked
  end

  test "try to unblock an unblocked item test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @turn)

    assert_raise FunctionClauseError, ~r/^no function clause matching/, fn ->
      Item.unblock(item, @turn)
    end
  end

  test "not_started? test" do
    assert Item.in_agree_urgency?(Item.new(@item_id))
    refute Item.in_agree_urgency?(Item.new(@item_id) |> Item.start(@owner_0, @turn))

    refute Item.in_agree_urgency?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.reject(@turn)
           )

    refute Item.in_agree_urgency?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "started? test" do
    assert Item.in_progress?(Item.new(@item_id) |> Item.start(@owner_0, @turn))
    refute Item.in_progress?(Item.new(@item_id))

    refute Item.in_progress?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.reject(@turn)
           )

    refute Item.in_progress?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "active? test" do
    assert Item.active?(Item.new(@item_id))

    assert Item.active?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )

    refute Item.active?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "blocked? test" do
    assert Item.blocked?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.block(@owner_0, @turn)
           )

    refute Item.blocked?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "finished? test" do
    assert Item.finished?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )

    refute Item.finished?(Item.new(@item_id))

    refute Item.finished?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "rejected? test" do
    assert Item.rejected?(Item.new(@item_id) |> Item.reject(@turn))
    refute Item.rejected?(Item.new(@item_id))

    refute Item.rejected?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
             |> Item.move_right(@turn)
           )
  end

  test "can_start? test" do
    assert Item.can_start?(new_item(), @no_wip_limits), "agree urgency items count"

    refute Item.can_start?(in_progress_item(0), @no_wip_limits),
           "My in_progress items don't count"

    refute Item.can_start?(in_progress_item(1), @no_wip_limits),
           "Other player's items don't count"

    refute Item.can_start?(completed_item(0), @no_wip_limits), "Completed items don't count"
    refute Item.can_start?(rejected_item(0), @no_wip_limits), "Rejected items don't count"
    refute Item.can_start?(blocked_item(0), @no_wip_limits), "Blocked items don't count"

    refute Item.can_start?(new_item(), %{1 => false, 2 => true, 3 => true}),
           "Blocked by WIP limit"
  end

  test "can_move? test" do
    assert Item.can_move?(in_progress_item(0), 0, @no_wip_limits), "My in_progress items count"
    refute Item.can_move?(new_item(), 0, @no_wip_limits), "agree urgency items don't count"

    refute Item.can_move?(in_progress_item(1), 0, @no_wip_limits),
           "Other player's items don't count"

    refute Item.can_move?(completed_item(0), 0, @no_wip_limits), "Completed items don't count"
    refute Item.can_move?(rejected_item(0), 0, @no_wip_limits), "Rejected items don't count"
    refute Item.can_move?(blocked_item(0), 0, @no_wip_limits), "Blocked items don't count"

    refute Item.can_move?(in_progress_item(0), 0, %{1 => false, 2 => true, 3 => false}),
           "Blocked by WIP limit"
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
    assert Item.can_help_move?(in_progress_item(1), 0, @no_wip_limits),
           "Other player's items count"

    refute Item.can_help_move?(in_progress_item(1), 1, @no_wip_limits), "My items don't count"
    refute Item.can_help_move?(blocked_item(1), 0, @no_wip_limits), "Blocked items don't count"
    refute Item.can_help_move?(new_item(), 0, @no_wip_limits), "Not started items don't count"

    refute Item.can_help_move?(completed_item(1), 0, @no_wip_limits),
           "Completed items don't count"

    refute Item.can_help_move?(rejected_item(1), 0, @no_wip_limits), "Rejected items don't count"

    refute Item.can_help_move?(in_progress_item(1), 0, %{1 => false, 2 => true, 3 => false}),
           "Blocked by WIP limit"
  end

  test "can_help_unblock? test" do
    assert Item.can_help_unblock?(blocked_item(1), 0), "Other player's blocked items count"
    refute Item.can_help_unblock?(blocked_item(1), 1), "My items don't count"

    refute Item.can_help_unblock?(in_progress_item(1), 0),
           "Other player's unblocked items don't count"

    refute Item.can_help_unblock?(new_item(), 0), "Not started items don't count"
    refute Item.can_help_unblock?(completed_item(1), 0), "Completed items don't count"
    refute Item.can_help_unblock?(rejected_item(1), 0), "Rejected items don't count"
  end

  def new_item(), do: Item.new(@item_id)

  def in_progress_item(player),
    do: Item.new(@item_id) |> Item.start(player, @turn) |> Item.move_right(@turn)

  def blocked_item(player),
    do: Item.new(@item_id) |> Item.start(player, @turn) |> Item.block(player, @turn)

  def completed_item(player) do
    Item.new(@item_id)
    |> Item.start(player, @turn)
    |> Item.move_right(@turn)
    |> Item.move_right(@turn)
    |> Item.move_right(@turn)
  end

  def rejected_item(_player) do
    Item.new(@item_id) |> Item.reject(@turn)
  end
end
