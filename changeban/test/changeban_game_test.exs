defmodule ChangebanGameTest do
  use ExUnit.Case, async: true
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
      %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()},
      %Player{id: 1, machine: :black, state: :new, options: Player.empty_options()}
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
    {:ok, player_id, game} = Game.new() |> Game.add_player()
    assert 1 == Game.player_count(game)
    assert 0 == player_id
  end

  def add_player_helper(game) do
    {:ok, _player_id, game} = Game.add_player(game)
    game
  end

  test "add five players" do
    game = Game.new()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()
    assert 5 == Game.player_count(game)
    assert 4 == Enum.find(game.players, &(&1.id == 4)).id
  end

  test "don't add more than five players" do
    game = Game.new()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()
      |> add_player_helper()

    assert {:error, "Already at max players"} == Game.add_player(game)
    assert 5 == Game.player_count(game)
    assert 4 == Enum.find(game.players, &(&1.id == 4)).id
  end


  test "player_options_after_start_game" do
    game = %{Game.new() | players: [Player.new(0)]}
    game_ = Game.start_game(game)
    actual_player = Game.get_player(game_, 0)

    expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
    expected_player = %Player{id: 0, state: :act, machine: actual_player.machine, options: expected_options}

    assert expected_player == actual_player
  end

  test "help response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
    game = %{s1b1c1r1_game() | players: [player]}
    expected_options = %{Player.empty_options() | hlp_mv: [0], hlp_unblk: [1]}

    expected_response = %Player{id: 0, machine: :black, options: expected_options, past: nil, state: :act}

    assert expected_response == Player.help_options(game.items, player)
  end

  test "black_options response 1 move, 1 unblock" do
    player = %Player{id: 1, machine: :black, state: :new, options: Player.empty_options()}
    game = %{s1b1c1r1_game() | players: [player]}
    expected_response = %Player{id: 1, machine: :black, past: nil, state: :act,
                                options: %{Player.empty_options() | block: [0]}}

    assert expected_response == Player.black_options(game.items, player)
  end

  test "black_options help response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
    game = %{s1b1c1r1_game() | players: [player]}
    expected_response = %Player{id: 0, machine: :black, past: nil, state: :act,
                                options: %{Player.empty_options() | hlp_mv: [0], hlp_unblk: [1]}}

    assert expected_response == Player.black_options(game.items, player)
  end

  test "red_options response 1 move, 1 unblock" do
    player = %Player{id: 1, machine: :black, state: :new, options: Player.empty_options()}
    game = %{s1b1c1r1_game() | players: [player]}
    expected_options = %{Player.empty_options() | move: [0], unblock: [1]}
    expected_response = %Player{id: 1, machine: :black, options: expected_options, past: nil, state: :act}

    assert expected_response == Player.red_options(game.items, player)
  end

  test "red_options help response 1 move, 1 unblock" do
    player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
    game = %{s1b1c1r1_game() | players: [player]}
    expected_options = %{Player.empty_options() | hlp_mv: [0], hlp_unblk: [1]}
    expected_response = %Player{id: 0, machine: :black, options: expected_options, past: nil, state: :act}

    assert expected_response == Player.red_options(game.items, player)
  end

  test "max score" do
    assert 20 == Game.calculate_score(won_game())
  end

  test "min score" do
     assert 10 == Game.calculate_score(min_score_game())
  end

  test "calculate red turn player options" do
    player = %Player{id: 0, machine: :red, state: :new, options: Player.empty_options()}
    game =
      %{Game.new() | players: [player]}

      expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
      expected_player = %Player{id: 0, machine: :red, state: :act, options: expected_options}
    assert expected_player == Player.calculate_player_options(game.items, player)
  end

  test "calculate red turn player options with nothing to move" do
    game = min_score_game()
    player = Enum.at(game.players, 0)
    expected_player = %Player{id: 0, machine: :red, state: :done, options: Player.empty_options()}
    assert expected_player == Player.calculate_player_options(game, player)
  end

  test "calculate help turn player options with nothing to move" do
    game = min_score_game()
    player = %Player{id: 0, machine: :red, state: :new, options: Player.empty_options()}
    expected_player = %Player{id: 0, machine: :red, state: :done, options: Player.empty_options()}
    assert expected_player == Player.calculate_player_options(game.items, player)
  end

  test "calculate black turn player start options" do
    player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
    game =
      %{Game.new() | players: [player]}

    expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
    expected_player = %Player{id: 0, machine: :black, state: :act, options: expected_options}
    assert expected_player == Player.calculate_player_options(game.items, player)
  end

  test "update_item" do
    changed_item = %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task}
    changed_player = %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()}
    game =
      Game.new()
      |> add_player_helper()
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

  test "exec_action, start an item" do
    item_id = 0
    game = Game.exec_action(all_states_game(), :start, item_id, 0)
    assert Game.get_item(game, item_id) |> Item.in_progress?
  end

  test "exec_action, move an item but do not complete" do
    item_id = 3
    game = Game.exec_action(all_states_game(), :move, item_id, 0)
    assert Game.get_item(game, item_id) |> Item.in_progress?
  end

  test "exec_action, progress to complete" do
    item_id = 1
    game = all_states_game()

    player = %{Game.get_player(game, 0) | machine: :red, options: %{Player.empty_options | start: [0], move: [1,3]}}
    game = %{game | players: [player]}
    game = Game.exec_action(game, :move, item_id, 0)
    assert Game.get_item(game, item_id) |> Item.complete?()
    expected_options = %{block: [], hlp_mv: [], hlp_unblk: [], move: [], reject: [0, 2, 3], start: [], unblock: []}
    assert expected_options == (Game.get_player(game, 0)).options
  end


  test "test black blocks then starts" do
    game = game_1()
    %{past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert nil == past

    game = Game.exec_action(game, :start, 1, 0)
    %{options: options, past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert :started == past
    assert %{Player.empty_options() | start: [], block: [0,1]} == options

    game = Game.exec_action(game, :block, 0, 0)
    %{options: options, state: state, past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert :done == state
    assert nil == past
    assert Player.empty_options() == options
  end

  test "test black starts then blocks" do
    game = game_1()
    %{past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert nil == past

    game = Game.exec_action(game, :block, 0, 0)
    %{options: options, past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert :blocked == past
    assert %{Player.empty_options() | start: [1,2], block: []} == options

    game = Game.exec_action(game, :start, 1, 0)
    %{options: options, state: state, past: past} = Game.get_player(game, 0)
    assert 2 == game.turn
    assert :done == state
    assert nil == past
    assert Player.empty_options() == options
  end

  test "completing" do
    game = about_to_complete_game()
    game = Game.exec_action(game, :move, 15, 0)
    options = (Game.get_player(game, 0)).options

    expected_options = %{block: [], hlp_mv: [], hlp_unblk: [], move: [], reject: Enum.to_list(0..14), start: [], unblock: []}
    assert expected_options == options
  end

  test "helping" do
    game = ready_to_help_game()
    game = Game.recalculate_state(game)
    player = Game.get_player(game, 1)

    expected_options = %{Player.empty_options() | hlp_unblk: [0,1]}
    assert expected_options == player.options
  end

  test "game over, everything done" do
    assert Game.game_over_all_done(min_score_game())
    refute Game.game_over_all_done(about_to_complete_game())
  end

  test "game over, player blocked" do
    assert Game.game_over_single_player_blocked(single_player_blocked_game())
  end

  test "game not over, player blocked, multiple players" do
    {:ok, _, game} = single_player_blocked_game() |> Game.add_player
    refute Game.game_over_single_player_blocked(game)
  end

  defp game_1() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: nil, state: 0, type: :change},
        %Changeban.Item{blocked: false, id: 2, owner: nil, state: 0, type: :task},
      ],
      players: [
        %Changeban.Player{id: 0, machine: :black, options: %{Player.empty_options() | start: [1, 2], block: [0]}, past: nil, state: :act},
        %Changeban.Player{id: 1, machine: :red,   options: %{Player.empty_options() | start: [1, 2]}, past: nil, state: :act}
      ],
      turn: 2,
      score: 0,
      max_players: 5
    }
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
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 4, machine: :black, state: :done, options: Player.empty_options()}
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
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()}
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
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()}
      ]
    } |> Game.start_game()
  end

  def single_player_blocked_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 2, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 5, type: :task},
      ],
      players: [
        %Changeban.Player {id: 0, machine: :black, options: Player.empty_options(), past: nil, state: :act}
      ],
      turn: 11,
      score: 2,
      max_players: 5
    }
  end

  def ready_to_help_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 2, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 5, type: :task},
      ],
      players: [
        %Changeban.Player {id: 0, machine: :black, options: Player.empty_options(), past: nil, state: :act},
        %Changeban.Player {id: 1, machine: :black, options: Player.empty_options(), past: nil, state: :act}
      ],
      turn: 11,
      score: 2,
      max_players: 5
    }
  end

  def all_states_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: nil, state: 0, type: :task},  # in_agree_urgency
        %Changeban.Item{blocked: false, id: 1, owner: 1, state: 3, type: :task},    # ready to complete
        %Changeban.Item{blocked: true, id: 2, owner: 1, state: 1, type: :task},     # blocked
        %Changeban.Item{blocked: false, id: 3, owner: 1, state: 1, type: :task},     # in_progress
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 4, type: :task},    # completed
        %Changeban.Item{blocked: false, id: 5, owner: 1, state: 5, type: :task},    # rejected
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: Player.empty_options()}
      ]
    } |> Game.start_game()
  end

  def about_to_complete_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 1, type: :change},
        %Changeban.Item{blocked: true, id: 2, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 3, owner: 0, state: 1, type: :change},
        %Changeban.Item{blocked: true, id: 4, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 5, owner: 0, state: 1, type: :change},
        %Changeban.Item{blocked: true, id: 6, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 7, owner: nil, state: 0, type: :change},
        %Changeban.Item{blocked: false, id: 8, owner: nil, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 9, owner: nil, state: 1, type: :change},
        %Changeban.Item{blocked: false, id: 10, owner: nil, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 11, owner: nil, state: 1, type: :change},
        %Changeban.Item{blocked: false, id: 12, owner: nil, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 13, owner: nil, state: 1, type: :change},
        %Changeban.Item{blocked: false, id: 14, owner: nil, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 15, owner: 0, state: 3, type: :change}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :red,
          options: %{block: [],
                     hlp_mv: [],
                     hlp_unblk: [],
                     move: [15],
                     reject: [],
                     start: [7, 8, 9, 10, 11, 12, 13, 14],
                     unblock: [0, 1, 2, 3, 4, 5, 6]},
          past: nil,
          state: :act},
      ],
      turn: 11,
      score: 0,
      max_players: 5
    }
  end

end
