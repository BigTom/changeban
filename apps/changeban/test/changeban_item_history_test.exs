defmodule ChangebanItemHistoryTest do
  use ExUnit.Case
  doctest Changeban.ItemHistory

  alias Changeban.{Game, ItemHistory, Item}

  @turn1 1
  @turn2 2
  @owner_id 1

  # @au  0 # Agree Urgency
  # Negotiate Change
  @nc 1
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

  describe "ItemHistory :moves tests" do
    test "Start Item" do
      history = ItemHistory.new() |> ItemHistory.start(@turn1)
      assert %ItemHistory{moves: %{@turn1 => @nc}} = history
    end

    test "Move Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(@turn1)
        |> ItemHistory.move(@va, @turn2)

      assert %ItemHistory{moves: %{@turn1 => @nc, @turn2 => @va}} = history
    end

    test "Reject Unstarted Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.reject(@rau, @turn1)

      assert %ItemHistory{moves: %{@turn1 => @rau}} = history
    end

    test "Reject Started Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(@turn1)
        |> ItemHistory.reject(@rnc, @turn2)

      assert %ItemHistory{moves: %{@turn1 => @nc, @turn2 => @rnc}} = history
    end

    test "Complete Item" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.move(@va, 5)
        |> ItemHistory.move(@vp, 9)
        |> ItemHistory.move(@c, 11)

      assert %ItemHistory{moves: %{1 => @nc, 5 => @va, 9 => @vp, 11 => @c}} = history
    end
  end

  # describe "ItemHistory :ends tests" do
  #   test "Start Item" do
  #     history = ItemHistory.new |> ItemHistory.start(@turn1)
  #     assert %ItemHistory{end: nil} = history
  #   end

  #   test "Move Item but do not finish" do
  #     history = ItemHistory.new
  #       |> ItemHistory.start(@turn1)
  #       |> ItemHistory.move(@nc, @turn2)

  #     assert %ItemHistory{end: nil} = history
  #   end

  #   test "Moves - Reject Unstarted Item" do
  #     history = ItemHistory.new
  #       |> ItemHistory.reject(@turn1)

  #     assert %ItemHistory{end: @turn1} = history
  #   end

  #   test "Reject Started Item" do
  #     history = ItemHistory.new
  #       |> ItemHistory.start(@turn1)
  #       |> ItemHistory.reject(@turn2)

  #     assert %ItemHistory{end: @turn2} = history
  #   end

  #   test "Complete Item" do
  #     history = ItemHistory.new
  #       |> ItemHistory.start(1)
  #       |> ItemHistory.move(@va, 5)
  #       |> ItemHistory.move(@vp, 9)
  #       |> ItemHistory.move(@c, 11)

  #     assert %ItemHistory{end: 11} = history
  #   end
  # end

  describe "ItemHistory :blocks & unblocks tests" do
    test "Start Item" do
      history = ItemHistory.new() |> ItemHistory.start(1)
      assert %ItemHistory{blocked: []} = history
    end

    test "Block Item" do
      history = ItemHistory.new() |> ItemHistory.start(1) |> ItemHistory.block(2)
      assert %ItemHistory{blocked: [{2, true}]} = history
    end

    test "unblock Item in same turn" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.block(2)
        |> ItemHistory.unblock(2)

      assert %ItemHistory{blocked: [{2, true}, {2, false}]} = history
    end

    test "unblock Item in different turn" do
      history =
        ItemHistory.new()
        |> ItemHistory.start(1)
        |> ItemHistory.block(2)
        |> ItemHistory.unblock(3)

      assert %ItemHistory{blocked: [{2, true}, {3, false}]} = history
    end
  end

  describe "Item and ItemHistory integration" do
    test "Start Item" do
      turn = 1
      item = Item.new(0) |> Item.start(@owner_id, turn)

      assert %ItemHistory{moves: %{^turn => @nc}} = item.history
    end

    test "Reject new Item" do
      turn = 1
      item = Item.new(0) |> Item.reject(turn)

      assert %ItemHistory{moves: %{^turn => @rau}} = item.history
    end
  end

  describe "generate turn history" do
    test "few items" do
      game =
        %{
          Game.new_short_game_for_testing()
          | turns: [:red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red]
        }
        |> add_player("A")
        |> add_player("B")
        |> Game.start_game()
        # history at turn 0
        |> Game.exec_action(:start, 0, 0)
        |> Game.exec_action(:start, 1, 1)
        # history at turn 1
        |> Game.exec_action(:move, 0, 0)
        |> Game.exec_action(:start, 2, 1)
        # history at turn 2
        |> Game.exec_action(:move, 0, 0)
        |> Game.exec_action(:move, 1, 1)
        # history at turn 3
        |> Game.exec_action(:move, 0, 0)
        |> Game.exec_action(:reject, 3, 0)
        |> Game.exec_action(:move, 1, 1)
        # history at turn 4
        |> Game.exec_action(:move, 1, 1)
        |> Game.exec_action(:reject, 2, 1)
        # history at turn 5

        IO.puts("GAME HISTORY #{game.turn}, #{inspect(game.history, pretty: true)}")
    end
  end

  # Turn 1 [
  #  {0, %{1 => 1}},
  #  {1, %{1 => 1}},
  #  {2, %{}},
  #  {3, %{}}]
  # Turn 2 [
  #  {0, %{1 => 1, 2 => 2}},
  #  {1, %{1 => 1}},
  #  {2, %{2 => 1}},
  #  {3, %{}}]
  # Turn 3 [
  #   {0, %{1 => 1, 2 => 2, 3 => 3}},
  #   {1, %{1 => 1, 3 => 2}},
  #   {2, %{2 => 1}},
  #   {3, %{}}]
  # Turn 4 [
  #   {0, %{1 => 1, 2 => 2, 3 => 3, 4 => 4}},
  #   {1, %{1 => 1, 3 => 2}},
  #   {2, %{2 => 1, 4 => 4}},
  #   {3, %{}}]
  # Turn 5 [
  #   {0, %{1 => 1, 2 => 2, 3 => 3, 4 => 4}},
  #   {1, %{1 => 1, 3 => 2, 4 => 3}},
  #   {2, %{2 => 1, 4 => 4}},
  #   {3, %{}}]

  def endstate_small_game() do
    %Changeban.Game{
      items: [
        %Changeban.Item{
          blocked: false,
          history: %Changeban.ItemHistory{
            blocked: [],
            moves: %{1 => 1, 2 => 2, 3 => 3, 4 => 4}
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
            moves: %{1 => 1, 2 => 2, 3 => 3, 4 => 4}
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
            moves: %{4 => 4}
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
            moves: %{4 => 4}
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
      turn: 4,
      turns: [:red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red, :red],
      wip_limits: {:none, 0}
    }
  end

  defp add_player(game, initials) do
    {:ok, _, game} = Game.add_player(game, initials)
    game
  end
end
