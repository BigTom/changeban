defmodule ChangebanGameTest do
  use ExUnit.Case
  doctest Changeban.Game
  alias Changeban.{Game, Item, Player}

  test "New game test number of items" do
    game = Game.new()
    assert Enum.count(game.items) == 16
  end

  test "New game test number of tasks" do
    game = Game.new()
    task_count = game.items |> Enum.filter(& ( &1.type == :task)) |> Enum.count
    change_count = game.items |> Enum.filter(& ( &1.type == :change)) |> Enum.count
    assert task_count == 8
    assert change_count == 8
  end

  test "New game test number of changes" do
    players = [
      %Player{id: 0, machine: :black, state: :new, options: nil},
      %Player{id: 1, machine: :black, state: :new, options: nil}
    ]
    game =
      %{Game.new() | players: players}
      |> Game.exec_action(:start, 4, 1)
    assert Game.get_item(game, 4).owner == 1
  end

  test "score at start" do
    assert 0 == Game.new() |> Game.calculate_score()
  end

  test "add a player" do
    game = Game.new() |> Game.add_player()
    assert 1 == Game.player_count(game)
    assert 0 == Enum.find(game.players, &(&1.id == 0)).id
  end

  test "add five players" do
    game = Game.new()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()
    assert 5 == Game.player_count(game)
    assert 4 == Enum.find(game.players, &(&1.id == 4)).id
  end

  test "don't add more than five players" do
    game = Game.new()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()
      |> Game.add_player()

    assert_raise RuntimeError, "Already at max players", fn -> Game.add_player(game) end
    assert 5 == Game.player_count(game)
    assert 4 == Enum.find(game.players, &(&1.id == 4)).id
  end

  test "player_red_moves_at_start" do
    game = Game.new() |> Game.add_player()
    player = Enum.at(game.players, 0)
    assert {:red, :act, [ move: [], unblock: [], start: Enum.to_list(0..15)]} == Game.red_options(game.items, player)
  end

  test "player_black_moves_at_start" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game = %{Game.new() | players: [player]}

    assert {:black, :start, [block: [], start: Enum.to_list(0..15)]} == Game.black_options(game.items, player)
  end

  test "help response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game = %{s1b1c1r1_game() | players: [player]}

    assert {:help, :act, [move: [0], unblock: [1]]} == Game.help_options(game.items, player)
  end

  test "black_options response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game = %{s1b1c1r1_game() | players: [player]}

    assert {:help, :act, [move: [0], unblock: [1]]} == Game.black_options(game.items, player)
  end

  test "red_options response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game = %{s1b1c1r1_game() | players: [player]}

    assert {:help, :act, [move: [0], unblock: [1]]} == Game.red_options(game.items, player)
  end

  test "max score" do
    assert 20 == Game.calculate_score(won_game())
  end

  test "min score" do
     assert 10 == Game.calculate_score(min_score_game())
  end

#   test "new turn" do
#     game =
#       Game.new()
#       |> Game.add_player()
#       |> Game.add_player()

#     player = Enum.fetch(game.players, 0)

#     assert :new == player.state
#  end

  test "calculate red turn player options" do
    player = %Player{id: 0, machine: :red, state: :new, options: nil}
    game =
      %{Game.new() | players: [player]}

    expected_player = %Player{id: 0, machine: :red, state: :act, options: [move: [], unblock: [], start: Enum.to_list(0..15)]}
    assert expected_player == Game.calculate_player_options(game, player)
  end

  test "calculate red turn player options with nothing to move" do
    game = min_score_game()
    player = Enum.at(game.players, 0)
    expected_player = %Player{id: 0, machine: :help, state: :done, options: [move: [], unblock: []]}
    assert expected_player == Game.calculate_player_options(game, player)
  end

  test "calculate help turn player options with nothing to move" do
    game = min_score_game()
    player = %Player{id: 0, machine: :help, state: :help, options: []}
    expected_player = %Player{id: 0, machine: :help, state: :done, options: [move: [], unblock: []]}
    assert expected_player == Game.calculate_player_options(game, player)
  end

  test "calculate black turn player start options" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game =
      %{Game.new() | players: [player]}

    expected_player = %Player{id: 0, machine: :black, state: :start, options: [block: [], start: Enum.to_list(0..15)]}
    assert expected_player == Game.calculate_player_options(game, player)
  end

  test "calculate black turn player block options" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    game =
      %Game{
        items: [
          %Changeban.Item{blocked: true, id: 0, owner: 1, state: 2, type: :task},
          %Changeban.Item{blocked: false, id: 1, owner: 0, state: 1, type: :task}
        ],
        players: [player]
      }

    expected_player = %Player{id: 0, machine: :black, state: :block, options: [block: [1], start: []]}
    assert expected_player == Game.calculate_player_options(game, player)
  end

  test "update_item" do
    changed_item = %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task}
    changed_player = %Changeban.Player{id: 0, machine: :red, state: :done, options: nil}
    game =
      Game.new()
      |> Game.add_player()
      |> Game.update_game(changed_item, changed_player)
    assert changed_item == Game.get_item(game, changed_item.owner)
  end

  test "exec_action, block" do
    item_id = 1
    game = Game.exec_action(all_states_game(), :block, item_id, 1)
    assert Game.get_item(game, item_id) |> Item.blocked?
  end

  test "exec_action, unblock" do
    item_id = 2
    game = Game.exec_action(all_states_game(), :unblock, item_id, 1)
    refute Game.get_item(game, item_id) |> Item.blocked?
  end
  test "exec_action, progress to start" do
    item_id = 0
    game = Game.exec_action(all_states_game(), :start, item_id, 0)
    assert Game.get_item(game, item_id) |> Item.in_progress?
  end
  test "exec_action, progress to complete" do
    item_id = 1
    player = %Player{id: 0, machine: :red, state: :new, options: nil}
    game =
      %{all_states_game() | players: [player]}
      |> Game.exec_action(:move, item_id, 0)
    assert Game.get_item(game, item_id) |> Item.complete?()
  end

  defp won_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 4, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 6, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 7, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 8, owner: 0, state: 5, type: :task},
        %Changeban.Item{blocked: false, id: 9, owner: 0, state: 5, type: :change},
        %Changeban.Item{blocked: false, id: 10, owner: 0, state: 6, type: :task},
        %Changeban.Item{blocked: false, id: 11, owner: 0, state: 6, type: :change},
        %Changeban.Item{blocked: false, id: 12, owner: 0, state: 7, type: :task},
        %Changeban.Item{blocked: false, id: 13, owner: 0, state: 7, type: :change},
        %Changeban.Item{blocked: false, id: 14, owner: 0, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 15, owner: 0, state: 8, type: :change}
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: nil},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: nil},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: nil},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: nil},
        %Changeban.Player{id: 4, machine: :black, state: :done, options: nil}
      ]
    }
  end

  def min_score_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 4, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 6, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 7, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 8, owner: 0, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 9, owner: 0, state: 8, type: :change},
        %Changeban.Item{blocked: false, id: 10, owner: 0, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 11, owner: 0, state: 8, type: :change},
        %Changeban.Item{blocked: false, id: 12, owner: 0, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 13, owner: 0, state: 8, type: :change},
        %Changeban.Item{blocked: false, id: 14, owner: 0, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 15, owner: 0, state: 8, type: :change}
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: nil},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: nil}
      ]
    }
  end

  def s1b1c1r1_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 1, state: 2, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 1, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 1, state: 5, type: :task},
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: nil},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: nil}
      ]
    }
  end

  def all_states_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: nil, state: 0, type: :task},  # in_agree_urgency
        %Changeban.Item{blocked: false, id: 1, owner: 1, state: 3, type: :task},    # in_progress
        %Changeban.Item{blocked: true, id: 2, owner: 1, state: 1, type: :task},     # blocked
        %Changeban.Item{blocked: false, id: 3, owner: 1, state: 4, type: :task},    # completed
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 5, type: :task},    # rejected
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: nil},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: nil},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: nil},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: nil}
      ]
    }
  end
end
