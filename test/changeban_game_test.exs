defmodule ChangebanGameTest do
  use ExUnit.Case, async: true
  doctest Changeban.Game
  alias Changeban.{Game, Item, Player}

  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  describe "New Game tests" do
    test "New game test number of items" do
      game = Game.new()
      assert Enum.count(game.items) == 16
    end

    test "New game test number of tasks" do
      game = Game.new()
      task_count = game.items |> Enum.filter(&(&1.type == :task)) |> Enum.count()
      change_count = game.items |> Enum.filter(&(&1.type == :change)) |> Enum.count()
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
      {:ok, player_id, game} = Game.new() |> Game.add_player("X")
      assert 1 == Game.player_count(game)
      assert 0 == player_id
    end

    test "can join when fewer than max players, otherwise cannot" do
      game =
        Game.new()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()

      assert Game.joinable?(game)
      assert not Game.joinable?(add_player_helper(game))
    end

    test "cannot join when not in setup" do
      game =
        Game.new()
        |> add_player_helper()

      assert Game.joinable?(game)

      assert not Game.joinable?(Game.start_game(game))
    end

    test "add five players" do
      game =
        Game.new()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()

      assert 5 == Game.player_count(game)
      assert 4 == Enum.find(game.players, &(&1.id == 4)).id
    end

    test "don't add more than five players" do
      game =
        Game.new()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()
        |> add_player_helper()

      assert {:error, "Already at max players"} == Game.add_player(game, "!!")
      assert 5 == Game.player_count(game)
      assert 4 == Enum.find(game.players, &(&1.id == 4)).id
    end
  end

  describe "Move options" do
    test "player_options_after_start_game" do
      {:ok, 0, base_game} = Game.new() |> Game.add_player("X")
      game = Game.start_game(base_game)
      actual_player = Game.get_player(game, 0)

      expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}

      expected_player = %Player{
        id: 0,
        state: :act,
        machine: actual_player.machine,
        options: expected_options,
        initials: "X"
      }

      assert expected_player == actual_player
    end

    test "help response 2 move, 1 unblock" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")

      expected_options = %{Player.empty_options() | hlp_mv: [4, 1], hlp_unblk: [0]}

      expected_response = %Player{
        id: 0,
        machine: :black,
        options: expected_options,
        past: nil,
        state: :help,
        initials: "X"
      }

      assert expected_response == Game.get_player(game, 0)
    end

    test "black_options response 1 block" do
      player = %Player{id: 1, machine: :black, state: :new, options: Player.empty_options()}
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")

      expected_response = %Player{
        id: 1,
        machine: :black,
        past: nil,
        state: :act,
        options: %{Player.empty_options() | block: [4, 1]}
      }

      assert expected_response == Player.black_options(game.items, player, @no_wip_limits)
    end

    test "black_options help response 2 move, 1 unblock" do
      player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")

      expected_response = %Player{
        id: 0,
        machine: :black,
        past: nil,
        state: :help,
        options: %{Player.empty_options() | hlp_mv: [4, 1], hlp_unblk: [0]}
      }

      assert expected_response == Player.black_options(game.items, player, @no_wip_limits)
    end

    test "red_options response 2 move, 1 unblock" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :red], "X")
      player = Game.get_player(game, 1)
      expected_options = %{Player.empty_options() | move: [4, 1], unblock: [0]}

      expected_response = %Player{
        id: 1,
        machine: :red,
        options: expected_options,
        past: nil,
        state: :act,
        initials: "R"
      }

      assert expected_response == Player.red_options(game.items, player, @no_wip_limits)
    end

    test "red_options response 1 moves, 1 unblock" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:red, :black], "X")
      player = %{Game.get_player(game, 0) | machine: :red}
      expected_options = %{Player.empty_options() | hlp_mv: [4, 1], hlp_unblk: [0]}

      expected_response = %Player{
        id: 0,
        machine: :red,
        options: expected_options,
        past: nil,
        state: :help,
        initials: "X"
      }

      assert expected_response == Player.red_options(game.items, player, @no_wip_limits)
    end

    test "max score" do
      assert 20 == Game.calculate_score(won_game())
    end

    test "min score" do
      assert 10 == Game.calculate_score(min_score_game())
    end

    test "calculate red day player options" do
      player = %Player{id: 0, machine: :red, state: :new, options: Player.empty_options()}
      game = %{Game.new() | players: [player]}

      expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
      expected_player = %Player{id: 0, machine: :red, state: :act, options: expected_options}

      assert expected_player ==
               Player.calculate_player_options(game.items, player, @no_wip_limits)
    end

    test "calculate red day player options with nothing to move" do
      game = min_score_game()
      player = Enum.at(game.players, 0)

      expected_player = %Player{
        id: 0,
        machine: :red,
        state: :done,
        options: Player.empty_options()
      }

      assert expected_player == Player.calculate_player_options(game, player, @no_wip_limits)
    end

    test "calculate help day player options with nothing to move" do
      game = min_score_game()
      player = %Player{id: 0, machine: :red, state: :new, options: Player.empty_options()}

      expected_player = %Player{
        id: 0,
        machine: :red,
        state: :done,
        options: Player.empty_options()
      }

      assert expected_player ==
               Player.calculate_player_options(game.items, player, @no_wip_limits)
    end

    test "calculate black day player start options" do
      player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
      game = %{Game.new() | players: [player]}

      expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
      expected_player = %Player{id: 0, machine: :black, state: :act, options: expected_options}

      assert expected_player ==
               Player.calculate_player_options(game.items, player, @no_wip_limits)
    end
  end

  describe "Actions" do
    test "update_item" do
      changed_item = %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task}

      changed_player = %Changeban.Player{
        id: 0,
        machine: :red,
        state: :done,
        options: Player.empty_options()
      }

      game =
        Game.new()
        |> add_player_helper()
        |> Game.start_game()
        |> Game.update_game(changed_item, changed_player)

      assert changed_item == Game.get_item(game, changed_item.owner)
    end

    test "exec_action, block" do
      item_id = 1
      game = Game.exec_action(all_states_game(), :block, item_id, 1)
      assert Game.get_item(game, item_id) |> Item.blocked?()
    end

    test "exec_action, unblock" do
      item_id = 2
      game = Game.exec_action(all_states_game(), :unblock, item_id, 1)
      refute Game.get_item(game, item_id) |> Item.blocked?()
    end

    test "exec_action, start an item" do
      item_id = 0
      game = Game.exec_action(all_states_game(), :start, item_id, 0)
      assert Game.get_item(game, item_id) |> Item.in_progress?()
    end

    test "exec_action, move an item but do not complete" do
      item_id = 3
      game = Game.exec_action(all_states_game(), :move, item_id, 0)
      assert Game.get_item(game, item_id) |> Item.in_progress?()
    end

    test "exec_action, progress to complete" do
      item_id = 1
      game = all_states_game()

      player = %{
        Game.get_player(game, 0)
        | machine: :red,
          options: %{Player.empty_options() | start: [0], move: [1, 3]}
      }

      game = %{game | players: [player]}
      game = Game.exec_action(game, :move, item_id, 0)
      assert Game.get_item(game, item_id) |> Item.complete?()

      expected_options = %{
        block: [],
        hlp_mv: [],
        hlp_unblk: [],
        move: [],
        reject: [0, 2, 3],
        start: [],
        unblock: []
      }

      assert expected_options == Game.get_player(game, 0).options
    end

    test "test black starts then does not block" do
      game = game_1()
      %{past: past} = Game.get_player(game, 0)
      assert 2 == game.day
      assert nil == past

      game = Game.exec_action(game, :start, 1, 0)
      %{options: options, past: past} = Game.get_player(game, 0)
      assert 2 == game.day
      assert :started == past
      assert Player.empty_options() == options
    end

    test "test black blocks then starts" do
      game = game_1()
      %{past: past} = Game.get_player(game, 0)
      assert 2 == game.day
      assert nil == past

      game = Game.exec_action(game, :block, 0, 0)
      %{options: options, past: past} = Game.get_player(game, 0)
      assert 2 == game.day
      assert :blocked == past
      assert %{Player.empty_options() | start: [1, 2], block: []} == options

      game = Game.exec_action(game, :start, 1, 0)
      %{options: options, state: state, past: past} = Game.get_player(game, 0)
      assert 2 == game.day
      assert :done == state
      assert nil == past
      assert Player.empty_options() == options
    end

    test "make a hlp_mv move should end up done" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")
      # can help items 0 or 1
      game1 = Game.exec_action(game, :hlp_mv, 4, 0)

      expected_player = %Player{
        id: 0,
        machine: :black,
        options: Player.empty_options(),
        past: nil,
        state: :done,
        initials: "X"
      }

      assert expected_player == Game.get_player(game1, 0)
    end

    test "make a hlp_unblk move should end up done" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")

      game1 = Game.exec_action(game, :hlp_unblk, 0, 0)

      expected_player = %Player{
        id: 0,
        machine: :black,
        options: Player.empty_options(),
        past: nil,
        state: :done,
        initials: "X"
      }

      assert expected_player == Game.get_player(game1, 0)
    end

    test "complete as hlp_mv should end up with a reject option" do
      game = one_nc_1_nc_x_1_vp_1_ac_1_rj_game([:black, :black], "X")

      game1 = Game.exec_action(game, :hlp_mv, 1, 0)

      expected_options = %{Player.empty_options() | reject: [0, 4]}

      expected_player = %Player{
        id: 0,
        machine: :black,
        options: expected_options,
        past: :completed,
        state: :help,
        initials: "X"
      }

      assert expected_player == Game.get_player(game1, 0)
    end

    test "completing" do
      game = about_to_complete_game()
      game = Game.exec_action(game, :move, 15, 0)
      options = Game.get_player(game, 0).options

      expected_options = %{
        block: [],
        hlp_mv: [],
        hlp_unblk: [],
        move: [],
        reject: Enum.to_list(0..14),
        start: [],
        unblock: []
      }

      assert expected_options == options
    end

    test "helping" do
      game = ready_to_help_game()
      game = Game.recalculate_state(game)
      player = Game.get_player(game, 1)

      expected_options = %{Player.empty_options() | hlp_unblk: [0, 1]}
      assert expected_options == player.options
    end

    test "game over, everything done" do
      assert Game.game_over_all_done(min_score_game())
      refute Game.game_over_all_done(about_to_complete_game())
    end

    test "game over, player blocked" do
      assert Game.all_blocked?(single_player_blocked_game())
    end

    test "game not over, player blocked, multiple players" do
      {:ok, _, game} = single_player_blocked_game() |> Game.add_player("X")
      refute Game.all_blocked?(game)
    end

    test "game not over, player about to block last item" do
      game = game_final_black_block()
      game = Game.exec_action(game, :block, 0, 0)
      assert Game.all_blocked?(game)
    end

    test "Getting correct day colors" do
      {:ok, 0, game0} =
        %{Game.new() | turns: [:red, :black, :red, :black]} |> Game.add_player("AA")

      game1 = game0 |> Game.start_game()
      assert game1.day == 1
      assert :red == Game.get_player(game1, 0).machine
      game2 = Game.new_day(game1)

      assert game2.day == 2
      assert :black == Game.get_player(game2, 0).machine
    end

    test "Getting correct day color sequence" do
      {:ok, 0, game0} =
        %{Game.new() | turns: [:red, :black, :red, :black]} |> Game.add_player("AA")

      game1 = game0 |> Game.start_game()
      assert game1.day == 1
      assert :red == Game.get_player(game1, 0).machine
      game2 = Game.exec_action(game1, :start, 1, 0)

      assert game2.day == 2
      assert :black == Game.get_player(game2, 0).machine
      game3 = Game.exec_action(game2, :block, 1, 0) |> Game.exec_action(:start, 2, 0)
      assert game3.day == 3
      assert :red == Game.get_player(game3, 0).machine
    end

    test "get correct list to reject" do
      player =
        game_finish()
        |> Game.recalculate_state()
        |> Game.exec_action(:move, 5, 0)
        |> Game.get_player(0)

      expected_options = %{Player.empty_options() | reject: [1, 2, 3, 4]}
      assert expected_options == player.options
    end
  end

  describe "WIP limits" do
    test "WIP limits off by default" do
      game = Game.new() |> add_player("X") |> Game.start_game()
      assert %{1 => true, 2 => true, 3 => true} = Game.wip_limited_states(game)
    end

    test "Std WIP limits off at start" do
      game =
        %{Game.new() | wip_limits: {:std, 1}, turns: [:red, :red, :red, :red]}
        |> add_player("X")
        |> Game.start_game()
        |> Game.exec_action(:start, 0, 0)
        |> Game.exec_action(:move, 0, 0)
        |> Game.exec_action(:start, 1, 0)

      assert %{1 => false, 2 => false, 3 => true} = Game.wip_limited_states(game)
    end

    test "CAP WIP limits integrate with open 2 limit" do
      game = %{Game.new() | wip_limits: {:cap, 2}} |> add_player("X") |> Game.start_game()

      assert %{1 => true, 2 => true, 3 => true} =
               Game.wip_limited_states(Game.exec_action(game, :start, 0, 0))
    end

    test "CAP WIP limits integrate with open" do
      game =
        %{Game.new() | wip_limits: {:cap, 1}, turns: [:red, :red, :red, :red]}
        |> add_player("X")
        |> Game.start_game()

      assert %{1 => true, 2 => true, 3 => true} == Game.wip_limited_states(game)

      assert %{1 => false, 2 => true, 3 => true} ==
               Game.wip_limited_states(Game.exec_action(game, :start, 0, 0))
    end
  end

  describe "Removing players" do
    test "removing player when no players has no impact" do
      game = Game.new()
      assert game == game |> Game.remove_player(0)
    end

    test "removing player from single player game  no impact" do
      game = Game.new() |> add_player("X") |> Game.start_game()

      game_after = Game.remove_player(game, 0)
      assert game.items == game_after.items
      assert Enum.empty?(game_after.players)
    end

    test "removing player during game setup does not affect items" do
      game = Game.new() |> add_player("X") |> add_player("Y")

      game_after = Game.remove_player(game, 0)
      assert game.items == game_after.items
      assert 1 == Enum.count(game_after.players)
    end

    test "removing player when game done does not affect items" do
      game = won_game()

      game_after = Game.remove_player(game, 0)
      assert won_game().items == game_after.items
      assert 4 == Enum.count(game_after.players)
    end

    test "remove player before any items started" do
      game = Game.new() |> add_player("X") |> add_player("Y") |> Game.start_game()

      game_after = Game.remove_player(game, 0)
      assert game.items == game_after.items
      assert 1 == Enum.count(game_after.players)
    end

    test "remove player with more owned items than remaining player count" do
      game = %Game{
        items: [
          %Changeban.Item{blocked: true, id: 1, owner: 0, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 2, owner: 0, state: 1, type: :task},
          %Changeban.Item{blocked: true, id: 3, owner: 1, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 5, owner: 0, state: 3, type: :task}
        ],
        players: [
          %Changeban.Player{id: 0, machine: :black, options: Player.empty_options()},
          %Changeban.Player{id: 1, machine: :red, options: Player.empty_options()},
          %Changeban.Player{id: 2, machine: :red, options: Player.empty_options()}
        ],
        state: :day
      }

      game_after = Game.remove_player(game, 0)

      expected_items = [
        %Changeban.Item{blocked: true, id: 1, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 2, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 3, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 1, state: 3, type: :task}
      ]

      assert expected_items == game_after.items
      assert 2 == Enum.count(game_after.players)
    end

    test "remove player with fewer owned items than remaining player count" do
      game = %Game{
        items: [
          %Changeban.Item{blocked: true, id: 1, owner: 2, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 2, owner: 2, state: 1, type: :task},
          %Changeban.Item{blocked: true, id: 3, owner: 1, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
          %Changeban.Item{blocked: false, id: 5, owner: 0, state: 3, type: :task}
        ],
        players: [
          %Changeban.Player{id: 0, machine: :black, options: Player.empty_options()},
          %Changeban.Player{id: 1, machine: :red, options: Player.empty_options()},
          %Changeban.Player{id: 2, machine: :red, options: Player.empty_options()}
        ],
        state: :day
      }

      game_after = Game.remove_player(game, 0)

      expected_items = [
        %Changeban.Item{blocked: true, id: 1, owner: 2, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 2, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 3, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 1, state: 3, type: :task}
      ]

      assert expected_items == game_after.items
      assert 2 == Enum.count(game_after.players)
    end
  end

  describe "Stats collection" do
    test "Stats at startup" do
      expected = %{
        turns: [["-", 0, 0, 0, 0, 0, 0, 0, 0, 0]],
        ticket_ages: [],
        median_age: 0,
        efficiency: 0,
        block_count: 0,
        help_count: 0,
        day: 0,
        score: 0,
        players: 0
      }

      assert ^expected = Game.stats(Game.new())
    end

    test "Day stats for shortgame" do
      game = ChangebanItemHistoryTest.short_game()

      expected_turns = [
        ["0", 0, 0, 0, 0, 0, 0, 0, 0, 4],
        ["1", 0, 0, 0, 0, 0, 0, 0, 2, 2],
        ["2", 0, 0, 0, 0, 0, 0, 1, 2, 1],
        ["3", 0, 0, 0, 0, 0, 1, 1, 1, 1],
        ["4", 0, 0, 0, 1, 1, 1, 0, 1, 0],
        ["5", 0, 0, 1, 1, 2, 0, 0, 0, 0]
      ]

      assert %{turns: ^expected_turns} = Game.stats(game)
    end

    test "Ticket age stats for shortgame" do
      game = ChangebanItemHistoryTest.short_game()

      assert %{ticket_ages: [%{x: 4, y: 3}, %{x: 5, y: 4}, %{x: 5, y: 3}, %{x: 4, y: 0}]} =
               Game.stats(game)
    end

    test "Ticket efficiency stats for shortgame" do
      game = ChangebanItemHistoryTest.short_game_with_blocks()
      assert %{efficiency: 0.7625} = Game.stats(game)
    end

    test "Ticket block count stats for shortgame" do
      game = ChangebanItemHistoryTest.short_game_with_blocks()
      assert %{block_count: 2} = Game.stats(game)
    end

    test "Day for shortgame" do
      game = ChangebanItemHistoryTest.short_game_with_blocks()
      assert %{day: 6} = Game.stats(game)
    end

    test "Helps for shortgame" do
      game = ChangebanItemHistoryTest.short_game_with_blocks_and_helps()
      assert %{help_count: 2} = Game.stats(game)
    end

    test "Median age for shortgame" do
      game = ChangebanItemHistoryTest.short_game_with_blocks_and_helps()
      assert %{median_age: 4.0} = Game.stats(game)
    end
  end

  def add_player_helper(game) do
    {:ok, _player_id, game} = Game.add_player(game, "X")
    game
  end

  defp game_finish() do
    %Game{
      items: [
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 3, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 0, state: 3, type: :task}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :black,
          options: %{Player.empty_options() | start: [1, 2], block: [0]},
          past: nil,
          state: :act
        },
        %Changeban.Player{
          id: 1,
          machine: :red,
          options: %{Player.empty_options() | start: [1, 2]},
          past: nil,
          state: :act
        }
      ],
      turns: [:red, :red, :red, :red, :red, :red],
      day: 2,
      score: 0,
      max_players: 5
    }
  end

  defp game_1() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: nil, state: 0, type: :change},
        %Changeban.Item{blocked: false, id: 2, owner: nil, state: 0, type: :task}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :black,
          options: %{Player.empty_options() | start: [1, 2], block: [0]},
          past: nil,
          state: :act
        },
        %Changeban.Player{
          id: 1,
          machine: :red,
          options: %{Player.empty_options() | start: [1, 2]},
          past: nil,
          state: :act
        }
      ],
      day: 2,
      score: 0,
      max_players: 5
    }
  end

  defp add_player(game, initials) do
    {:ok, _, game} = Game.add_player(game, initials)
    game
  end

  # :started %{block: [2], hlp_mv: [], hlp_unblk: [], move: [], reject: [], start: [], unblock: []}
  defp game_final_black_block() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 1, type: :change}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :black,
          options: %{Player.empty_options() | block: [0]},
          past: :started,
          state: :act
        }
      ],
      day: 2,
      score: 0,
      max_players: 5
    }
  end

  defp won_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: false, id: 0, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: 1, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 2, owner: 2, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 3, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 4, owner: 4, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 5, owner: 0, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 6, owner: 1, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 7, owner: 2, state: 4, type: :change},
        %Changeban.Item{blocked: false, id: 8, owner: 3, state: 5, type: :task},
        %Changeban.Item{blocked: false, id: 9, owner: 4, state: 5, type: :change},
        %Changeban.Item{blocked: false, id: 10, owner: 0, state: 6, type: :task},
        %Changeban.Item{blocked: false, id: 11, owner: 1, state: 6, type: :change},
        %Changeban.Item{blocked: false, id: 12, owner: 2, state: 7, type: :task},
        %Changeban.Item{blocked: false, id: 13, owner: 3, state: 7, type: :change},
        %Changeban.Item{blocked: false, id: 14, owner: 4, state: 8, type: :task},
        %Changeban.Item{blocked: false, id: 15, owner: 0, state: 8, type: :change}
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 4, machine: :black, state: :done, options: Player.empty_options()}
      ],
      state: :done
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

  def one_nc_1_nc_x_1_vp_1_ac_1_rj_game(machines_list, initials) do
    game = %Game{
      items: [
        %Changeban.Item{blocked: true, id: 0, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 1, type: :task},
        %Changeban.Item{blocked: false, id: 1, owner: 1, state: 3, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 1, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 5, type: :task}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: nil,
          state: :done,
          options: Player.empty_options(),
          initials: initials
        },
        %Changeban.Player{
          id: 1,
          machine: nil,
          state: :done,
          options: Player.empty_options(),
          initials: "R"
        }
      ],
      turns: machines_list
    }

    Game.start_game(game)
  end

  def single_player_blocked_game() do
    %Game{
      items: [
        %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
        %Changeban.Item{blocked: true, id: 1, owner: 0, state: 2, type: :task},
        %Changeban.Item{blocked: false, id: 2, owner: 0, state: 4, type: :task},
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 5, type: :task}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :black,
          options: Player.empty_options(),
          past: nil,
          state: :act
        }
      ],
      day: 11,
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
        %Changeban.Item{blocked: false, id: 3, owner: 0, state: 5, type: :task}
      ],
      players: [
        %Changeban.Player{
          id: 0,
          machine: :black,
          options: Player.empty_options(),
          past: nil,
          state: :act
        },
        %Changeban.Player{
          id: 1,
          machine: :black,
          options: Player.empty_options(),
          past: nil,
          state: :act
        }
      ],
      day: 11,
      score: 2,
      max_players: 5
    }
  end

  def all_states_game() do
    %Game{
      items: [
        # in_agree_urgency
        %Changeban.Item{blocked: false, id: 0, owner: nil, state: 0, type: :task},
        # ready to complete
        %Changeban.Item{blocked: false, id: 1, owner: 1, state: 3, type: :task},
        # blocked
        %Changeban.Item{blocked: true, id: 2, owner: 1, state: 1, type: :task},
        # in_progress
        %Changeban.Item{blocked: false, id: 3, owner: 1, state: 1, type: :task},
        # completed
        %Changeban.Item{blocked: false, id: 4, owner: 1, state: 4, type: :task},
        # rejected
        %Changeban.Item{blocked: false, id: 5, owner: 1, state: 5, type: :task}
      ],
      players: [
        %Changeban.Player{id: 0, machine: :red, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 1, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 2, machine: :black, state: :done, options: Player.empty_options()},
        %Changeban.Player{id: 3, machine: :black, state: :done, options: Player.empty_options()}
      ],
      turns: [:red, :black, :black, :black]
    }
    |> Game.start_game()
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
          options: %{
            block: [],
            hlp_mv: [],
            hlp_unblk: [],
            move: [15],
            reject: [],
            start: [7, 8, 9, 10, 11, 12, 13, 14],
            unblock: [0, 1, 2, 3, 4, 5, 6]
          },
          past: nil,
          state: :act
        }
      ],
      day: 11,
      score: 0,
      max_players: 5
    }
  end
end
