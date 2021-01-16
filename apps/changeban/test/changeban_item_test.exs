defmodule ChangebanItemTest do
  use ExUnit.Case
  doctest Changeban.Item

  alias Changeban.Item

  @no_wip_limits %{1 => true, 2 => true, 3 => true}
  @day 0
  @owner_0 0
  @owner_1 0
  @item_id 1

  test "New item" do
    assert %Item{blocked: false, id: 3, owner: nil, state: 0, type: :change} == Item.new(3)
    assert %Item{blocked: false, id: 4, owner: nil, state: 0, type: :task} == Item.new(4)
  end

  test "Start an item" do
    started = Item.new(@item_id) |> Item.start(@owner_0, @day)

    assert %Item{blocked: false, id: @item_id, owner: @owner_0, state: 1} = started
  end

  test "Start a started item" do
    started = Item.new(@item_id) |> Item.start(@owner_0, @day)

    assert_raise RuntimeError, "Trying to start a started item", fn ->
      Item.start(started, @owner_1, @day)
    end
  end

  test "basic move_right test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @day)
    assert 2 == Item.move_right(item, @day).state
  end

  test "will move_right to complete" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)

    assert 4 == Item.move_right(item, @day).state
  end

  test "won't move completed items move_right test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)

    assert_raise RuntimeError, "Trying to move a completed item", fn ->
      Item.move_right(item, @day)
    end
  end

  test "basic reject test" do
    item = Item.new(@item_id)
    assert 5 == Item.reject(item, @day).state
  end

  test "latest chance to reject test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)

    assert 8 == Item.reject(item, @day).state
  end

  test "cannot reject completed item test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)

    assert_raise RuntimeError, "Trying to reject a completed item", fn ->
      Item.reject(item, @day)
    end
  end

  test "basic block test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @day)
    assert Item.block(item, @owner_0, @day).blocked
  end

  test "block failure cannot block unstarted item test" do
    test_id = 7
    item = Item.new(test_id)

    assert_raise RuntimeError,
                 ~r/^Player 0 cannot block %Changeban.Item/,
                 fn -> Item.block(item, @owner_0, @day) end
  end

  test "block failure cannot block completed item test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)
      |> Item.move_right(@day)

    assert_raise UndefinedFunctionError,
                 "function Changeban.Item.block/2 is undefined or private",
                 fn -> Item.block(item, 0) end
  end

  test "block failure cannot block rejected item test" do
    item =
      Item.new(@item_id)
      |> Item.reject(@day)

    assert_raise UndefinedFunctionError,
                 "function Changeban.Item.block/2 is undefined or private",
                 fn -> Item.block(item, 0) end
  end

  test "basic unblock test" do
    item =
      Item.new(@item_id)
      |> Item.start(@owner_0, @day)
      |> Item.block(@owner_0, @day)

    refute Item.unblock(item, @day).blocked
  end

  test "try to unblock an unblocked item test" do
    item = Item.new(@item_id) |> Item.start(@owner_0, @day)

    assert_raise FunctionClauseError, ~r/^no function clause matching/, fn ->
      Item.unblock(item, @day)
    end
  end

  test "not_started? test" do
    assert Item.in_agree_urgency?(Item.new(@item_id))
    refute Item.in_agree_urgency?(Item.new(@item_id) |> Item.start(@owner_0, @day))

    refute Item.in_agree_urgency?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.reject(@day)
           )

    refute Item.in_agree_urgency?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )
  end

  test "started? test" do
    assert Item.in_progress?(Item.new(@item_id) |> Item.start(@owner_0, @day))
    refute Item.in_progress?(Item.new(@item_id))

    refute Item.in_progress?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.reject(@day)
           )

    refute Item.in_progress?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )
  end

  test "active? test" do
    assert Item.active?(Item.new(@item_id))

    assert Item.active?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )

    refute Item.active?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )
  end

  test "blocked? test" do
    assert Item.blocked?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.block(@owner_0, @day)
           )

    refute Item.blocked?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )
  end

  test "finished? test" do
    assert Item.finished?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )

    refute Item.finished?(Item.new(@item_id))

    refute Item.finished?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
           )
  end

  test "rejected? test" do
    assert Item.rejected?(Item.new(@item_id) |> Item.reject(@day))
    refute Item.rejected?(Item.new(@item_id))

    refute Item.rejected?(
             Item.new(@item_id)
             |> Item.start(@owner_0, @day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
             |> Item.move_right(@day)
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

  describe "Stats collection" do
    test "collect ages" do
      game = ChangebanItemHistoryTest.short_game()
      assert [%{x: 4, y: 3}, %{x: 5, y: 4}, %{x: 5, y: 3}, %{x: 4, y: 0}] = Item.ages(game.items)
    end

    test "median age test odd number" do
      items = [
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{blocked: [], done: 4, helped: [], start: 1},
          id: 0,
          owner: 0,
          state: 4,
          type: :task
        },
        %Changeban.Item{
          blocked: true,
          history: %Changeban.ItemHistory{blocked: [5, 4, 2], done: 7, helped: [], start: 1},
          id: 1,
          owner: 1,
          state: 6,
          type: :change
        },
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{blocked: [5, 3], done: 7, helped: [6, 5], start: 2},
          id: 2,
          owner: 1,
          state: 4,
          type: :task
        }
      ]
      assert 5 = Item.median_age(items)
    end
    test "median age test even number half value" do
      items = [
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{blocked: [], done: 4, helped: [], start: 1},
          id: 0,
          owner: 0,
          state: 4,
          type: :task
        },
        %Changeban.Item{
          blocked: true,
          history: %Changeban.ItemHistory{blocked: [5, 4, 2], done: 7, helped: [], start: 1},
          id: 1,
          owner: 1,
          state: 6,
          type: :change
        },
      ]
      assert 4.5 = Item.median_age(items)
    end
  end

  def new_item(), do: Item.new(@item_id)

  def in_progress_item(player),
    do: Item.new(@item_id) |> Item.start(player, @day) |> Item.move_right(@day)

  def blocked_item(player),
    do: Item.new(@item_id) |> Item.start(player, @day) |> Item.block(player, @day)

  def completed_item(player) do
    Item.new(@item_id)
    |> Item.start(player, @day)
    |> Item.move_right(@day)
    |> Item.move_right(@day)
    |> Item.move_right(@day)
  end

  def rejected_item(_player) do
    Item.new(@item_id) |> Item.reject(@day)
  end
end
