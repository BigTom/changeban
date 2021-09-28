defmodule ChangebanItemHistoryTest do
  use ExUnit.Case
  doctest Changeban.ItemHistory

  alias Changeban.{Game, ItemHistory, Item}

  @turn1 1
  @turn2 2
  @owner_0 0
  @owner_1 1

  # @au  0 # Agree Urgency
  # Negotiate Change
  # @nc 1
  # Validate Adoption
  @va 2
  # Verify Performance
  @vp 3
  # Complete
  @c 4
  # RAU Rejected - Agree Urgency
  @rau 5
  # Rejected - Negotiate Change
  @rnc 6
  # @rva 7 # Rejected - Validate Adoption
  # @rvp 8 # Rejected - Verify Performance

  describe "ItemHistory new() and :start tests" do
    test "New item history" do
      assert %ItemHistory{} == ItemHistory.new()
    end
  end

  describe "ItemHistory :start & :done tests" do
    test "Unstarted Item" do
      assert %ItemHistory{start: nil} = ItemHistory.new()
    end

    test "Start Item" do
      history = ItemHistory.new() |> ItemHistory.start(@turn1)
      assert %ItemHistory{start: @turn1} = history
    end

    test "Move Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(@turn1)
        |> ItemHistory.move(@va, @turn2)

      assert %ItemHistory{start: @turn1} = history
    end

    test "Reject Unstarted Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.reject(@rau, @turn1)

      assert %ItemHistory{start: @turn1, done: @turn1} = history
    end

    test "Reject Started Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(@turn1)
        |> ItemHistory.reject(@rnc, @turn2)

      assert %ItemHistory{start: @turn1, done: @turn2} = history
    end

    test "Complete Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.move(@va, 5)
        |> ItemHistory.move(@vp, 9)
        |> ItemHistory.move(@c, 11)

      assert %ItemHistory{start: 1, done: 11} = history
    end
  end

  describe "ItemHistory :blocks & unblocks tests" do
    test "Start Item" do
      history = ItemHistory.new() |> ItemHistory.start(1)
      assert %ItemHistory{blocked: []} = history
    end

    test "Block Item" do
      history = ItemHistory.new() |> ItemHistory.start(1) |> ItemHistory.block(2)
      assert %ItemHistory{blocked: [2]} = history
    end

    test "unblock Item in same day" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.block(2)
        |> ItemHistory.unblock(2)

      assert %ItemHistory{blocked: [2, 2]} = history
    end

    test "unblock Item in different day" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.block(2)
        |> ItemHistory.unblock(3)

      assert %ItemHistory{blocked: [3, 2]} = history
    end
  end

  describe "Item and ItemHistory integration" do
    test "Start Item" do
      day = 1
      item = Item.new(0) |> Item.start(@owner_0, day)

      assert %ItemHistory{start: ^day} = item.history
    end

    test "Reject new Item" do
      day = 1
      item = Item.new(0) |> Item.reject(day)

      assert %ItemHistory{start: ^day, done: ^day} = item.history
    end
  end

  describe "ticket age tests" do
    test "unstarted ticket has no age" do
      item = Item.new(0)
      assert 0 = ItemHistory.age(item.history, 3)
    end

    test "unstarted & rejected ticket has no age" do
      item = Item.new(0) |> Item.reject(5)
      assert 0 = ItemHistory.age(item.history, 7)
    end

    test "started ticket has age from start to day" do
      item = Item.new(0) |> Item.start(@owner_0, 3)
      assert 5 = ItemHistory.age(item.history, 8)
    end

    test "started and done ticket has age from start to done" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.move(@va, 5)
        |> ItemHistory.move(@vp, 9)
        |> ItemHistory.move(@c, 11)

      assert 10 = ItemHistory.age(history, 17)
    end
  end

  describe "ticket blocked tests" do
    test "unstarted ticket has no blocked time" do
      item = Item.new(0)
      assert 0 = ItemHistory.blocked_time(item.history, 8)
    end

    test "started ticket has no blocked time" do
      item = Item.new(0) |> Item.start(@owner_0, 3)
      assert 0 = ItemHistory.blocked_time(item.history, 8)
    end

    test "started & blocked ticket is blocked to current day" do
      item = Item.new(0) |> Item.start(@owner_0, 3) |> Item.block(@owner_0, 5)
      assert 3 = ItemHistory.blocked_time(item.history, 8)
    end

    test "started & blocked one same day ticket has no blocked time" do
      item = Item.new(0) |> Item.start(@owner_0, 3) |> Item.block(@owner_0, 5) |> Item.unblock(5)
      assert 0 = ItemHistory.blocked_time(item.history, 8)
    end

    test "multiple blocks then finished" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.block(1, 1)
        |> Item.unblock(2)
        |> Item.move_right(3)
        |> Item.block(1, 4)
        |> Item.unblock(6)
        |> Item.block(1, 7)
        |> Item.unblock(7)
        |> Item.move_right(8)
        |> Item.move_right(8)

      assert 3 = ItemHistory.blocked_time(item.history, 8)
    end
  end

  describe "ticket efficiency" do
    test "unfinished item has 0% efficiency" do
      item = Item.new(0)
      assert 0 = ItemHistory.efficency(item.history)
    end

    test "unstarted, rejected item has 100% efficiency" do
      item = Item.new(0) |> Item.reject(1)
      assert 1 = ItemHistory.efficency(item.history)
    end

    test "started, completed, unblocked item has 100% efficiency" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.move_right(3)
        |> Item.move_right(8)
        |> Item.move_right(8)

      assert 1.0 = ItemHistory.efficency(item.history)
    end

    test "blocked & unblocked on same day leaves 100% efficiency" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.block(1, 1)
        |> Item.unblock(1)
        |> Item.reject(2)

      assert 1.0 = ItemHistory.efficency(item.history)
    end

    test "blocked 2, age 4 gives 50% efficiency" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.block(1, 1)
        |> Item.unblock(3)
        |> Item.reject(5)

      assert 0.5 = ItemHistory.efficency(item.history)
    end
  end

  describe "block counts" do
    test "unstarted item has 0 block count" do
      item = Item.new(0) |> Item.start(1, 1) |> Item.reject(5)
      assert 0 = ItemHistory.block_count(item.history)
    end

    test "started, rejected item has 0 block count" do
      item = Item.new(0)
      assert 0 = ItemHistory.block_count(item.history)
    end

    test "started, blocked item has block count 1" do
      item = Item.new(0) |> Item.start(1, 1) |> Item.block(1, 2)
      assert 1 = ItemHistory.block_count(item.history)
    end

    test "started, blocked, unblocked item has block count 1" do
      item = Item.new(0) |> Item.start(1, 1) |> Item.block(1, 2) |> Item.unblock(3)
      assert 1 = ItemHistory.block_count(item.history)
    end

    test "started, blocked twice, unblocked and rejected item has block count 2" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.block(1, 2)
        |> Item.unblock(3)
        |> Item.block(1, 3)
        |> Item.reject(5)

      assert 2 = ItemHistory.block_count(item.history)
    end

    test "started, blocked twice, unblocked twice has block count 2" do
      item =
        Item.new(0)
        |> Item.start(1, 1)
        |> Item.block(1, 2)
        |> Item.unblock(3)
        |> Item.block(1, 3)
        |> Item.unblock(3)

      assert 2 = ItemHistory.block_count(item.history)
    end
  end

  describe "help counts" do
    test "mark helped" do
      item_history = ItemHistory.new() |> ItemHistory.help(2)
      assert %ItemHistory{helped: [2]} = item_history
    end

    test "multiple help" do
      item_history =
        ItemHistory.new() |> ItemHistory.help(2) |> ItemHistory.help(2) |> ItemHistory.help(4)

      assert %ItemHistory{helped: [4, 2, 2]} = item_history
    end

    test "unhelped help count" do
      item_history = ItemHistory.new()
      assert 0 == ItemHistory.help_count(item_history)
    end

    test "helped help count" do
      item_history =
        ItemHistory.new() |> ItemHistory.help(2) |> ItemHistory.help(2) |> ItemHistory.help(4)

      assert 3 == ItemHistory.help_count(item_history)
    end

    test "Item move integration help count" do
      item = Item.new(0) |> Item.start(0, 1) |> Item.help_move_right(2)
      assert %Item{history: %ItemHistory{helped: [2]}} = item
    end

    test "Item unblock integration help count" do
      item = Item.new(0) |> Item.start(0, 1) |> Item.block(0, 2) |> Item.help_unblock(3)
      assert %Item{history: %ItemHistory{helped: [3]}} = item
    end
  end

  # test "capture" do
  #   short_game_with_blocks_with_capture()
  # end

  def short_game() do
    %{
      Game.new_short_game_for_testing()
      | turns: [:red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red]
    }
    |> add_player("A")
    |> add_player("B")
    |> Game.start_game()
    # history at day 0
    |> Game.exec_action(:start, 0, 0)
    |> Game.exec_action(:start, 1, 1)
    # history at day 1
    |> Game.exec_action(:move, 0, 0)
    |> Game.exec_action(:start, 2, 1)
    # history at day 2
    |> Game.exec_action(:move, 0, 0)
    |> Game.exec_action(:move, 1, 1)
    # history at day 3
    |> Game.exec_action(:move, 0, 0)
    |> Game.exec_action(:reject, 3, 0)
    |> Game.exec_action(:move, 1, 1)
    # history at day 4
    |> Game.exec_action(:move, 1, 1)
    |> Game.exec_action(:reject, 2, 1)
  end

  def short_game_with_blocks() do
    %{
      Game.new_short_game_for_testing()
      | turns: [:red, :red, :black, :black, :red, :red, :red, :red, :red, :red, :red, :red]
    }
    |> add_player("A")
    |> add_player("B")
    |> Game.start_game()
    # history at day 0
    # 1
    |> Game.exec_action(:start, 0, 0)
    # 1
    |> Game.exec_action(:start, 1, 1)
    # history at day 1
    # 1
    |> Game.exec_action(:block, 0, 0)
    # 1
    |> Game.exec_action(:block, 1, 1)
    # 1
    |> Game.exec_action(:start, 2, 0)
    # 1
    |> Game.exec_action(:start, 3, 1)
    # history at day 2
    # 2
    |> Game.exec_action(:move, 2, 0)
    # 1
    |> Game.exec_action(:unblock, 1, 1)
    # history at day 3
    # 3
    |> Game.exec_action(:move, 2, 0)
    # 2
    |> Game.exec_action(:move, 1, 1)
    # history at day 4
    # 4 *
    |> Game.exec_action(:move, 2, 0)
    # 5 *
    |> Game.exec_action(:reject, 0, 0)
    # 3
    |> Game.exec_action(:move, 1, 1)
    # history at day 5
    # 4 *
    |> Game.exec_action(:move, 1, 1)
    # 5 *
    |> Game.exec_action(:reject, 3, 1)
  end

  def short_game_with_blocks_and_helps() do
    %{
      Game.new_short_game_for_testing()
      | # t1
        turns: [
          :red,
          :black,
          # t2
          :red,
          :black,
          # t3
          :red,
          :black,
          # t4
          :red,
          :red,
          # t5
          :red,
          :black,
          # t6
          :red,
          :red,
          # t7
          :red,
          :red
        ]
    }
    |> add_player("A")
    |> add_player("B")
    |> Game.start_game()
    # history at day 0
    # 1
    |> Game.exec_action(:start, 0, @owner_0)
    # 1
    |> Game.exec_action(:start, 1, @owner_1)
    # history at day 1
    # 2
    |> Game.exec_action(:move, 0, @owner_0)
    # 1
    |> Game.exec_action(:block, 1, @owner_1)
    # 1
    |> Game.exec_action(:start, 2, @owner_1)
    # history at day 2
    # 3
    |> Game.exec_action(:move, 0, @owner_0)
    # 1
    |> Game.exec_action(:block, 2, @owner_1)
    # 1
    |> Game.exec_action(:start, 3, @owner_1)
    # history at day 3
    # 4
    |> Game.exec_action(:move, 0, @owner_0)
    # 5 *
    |> Game.exec_action(:reject, 3, @owner_0)
    # 1
    |> Game.exec_action(:unblock, 1, @owner_1)
    # history at day 4
    # 1
    |> Game.exec_action(:hlp_unblk, 2, @owner_0)
    # 1
    |> Game.exec_action(:block, 1, @owner_1)
    # history at day 5
    # 2
    |> Game.exec_action(:hlp_mv, 2, @owner_0)
    # 3
    |> Game.exec_action(:move, 2, @owner_1)
    # history at day 6
    # 4
    |> Game.exec_action(:move, 2, @owner_1)
    # 5 *
    |> Game.exec_action(:reject, 1, @owner_1)

    # history at day 7
  end

  def endstate_small_game() do
    %Changeban.Game{
      items: [
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{
            blocked: [],
            start: 1,
            done: 4
          },
          id: 0,
          owner: 0,
          state: 4,
          type: :task
        },
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{
            blocked: [],
            start: 1,
            done: 4
          },
          id: 1,
          owner: 1,
          state: 4,
          type: :change
        },
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{
            blocked: [],
            start: 4,
            done: 4
          },
          id: 2,
          owner: nil,
          state: 5,
          type: :task
        },
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{
            blocked: [],
            start: 4,
            done: 4
          },
          id: 3,
          owner: nil,
          state: 5,
          type: :change
        }
      ],
      max_players: 5,
      players: [
        %Changeban.Player{
          id: 0,
          initials: "A",
          machine: :red,
          name: nil,
          options: %{
            block: [],
            hlp_mv: [],
            hlp_unblk: [],
            move: [],
            reject: [],
            start: [],
            unblock: []
          },
          past: :completed,
          state: :done
        },
        %Changeban.Player{
          id: 1,
          initials: "B",
          machine: :red,
          name: nil,
          options: %{
            block: [],
            hlp_mv: [],
            hlp_unblk: [],
            move: [],
            reject: [],
            start: [],
            unblock: []
          },
          past: :completed,
          state: :done
        }
      ],
      score: 5,
      state: :done,
      day: 4,
      turns: [:red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red],
      wip_limits: {:none, 0}
    }
  end

  defp add_player(game, initials) do
    {:ok, _, game} = Game.add_player(game, initials)
    game
  end

  def short_game_with_blocks_with_capture() do
    history_track = []

    game =
      %{
        Game.new_short_game_for_testing()
        | turns: [:red, :red, :black, :black, :red, :red, :red, :red, :red, :red, :red, :red]
      }
      |> add_player("A")
      |> add_player("B")
      |> Game.start_game()

    history_track = [Game.stats(game) | history_track]
    # history at day 0
    game =
      game
      # 1
      |> Game.exec_action(:start, 0, 0)
      # 1
      |> Game.exec_action(:start, 1, 1)

    history_track = [Game.stats(game) | history_track]
    # history at day 1
    game =
      game
      # 1
      |> Game.exec_action(:block, 0, 0)
      # 1
      |> Game.exec_action(:block, 1, 1)
      # 1
      |> Game.exec_action(:start, 2, 0)
      # 1
      |> Game.exec_action(:start, 3, 1)

    history_track = [Game.stats(game) | history_track]
    # history at day 2
    game =
      game
      # 2
      |> Game.exec_action(:move, 2, 0)
      # 1
      |> Game.exec_action(:unblock, 1, 1)

    history_track = [Game.stats(game) | history_track]
    # history at day 3
    game =
      game
      # 3
      |> Game.exec_action(:move, 2, 0)
      # 2
      |> Game.exec_action(:move, 1, 1)

    history_track = [Game.stats(game) | history_track]
    # history at day 4
    game =
      game
      # 4 *
      |> Game.exec_action(:move, 2, 0)
      # 5 *
      |> Game.exec_action(:reject, 0, 0)
      # 3
      |> Game.exec_action(:move, 1, 1)

    history_track = [Game.stats(game) | history_track]
    # history at day 5
    game =
      game
      # 4 *
      |> Game.exec_action(:move, 1, 1)
      # 5 *
      |> Game.exec_action(:reject, 3, 1)

    history_track = [Game.stats(game) | history_track]

    IO.puts("GAME HISTORY HISTORY -
          #{inspect(Enum.reverse(history_track), pretty: true)}")
    game
  end
end
