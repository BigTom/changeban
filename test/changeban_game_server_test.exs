defmodule ChangebanGameServerTest do
  use ExUnit.Case, async: false
  # doctest Changeban.GameServer

  alias Changeban.{GameSupervisor, GameServer, Game}

  setup do
    game_name = "#{Enum.random(0..999999)}"

    on_exit fn ->
      GameSupervisor.close_game(game_name)
    end

    GameSupervisor.create_game(game_name)

    {:ok, game_name: game_name}
  end

  test "add player to game", %{game_name: game_name} do
    {:ok, player_id, game} = GameServer.add_player(game_name, "X")
    assert 0 == player_id
    assert 1 = Game.player_count(game)
    actual_game = Game.start_game(game)
    assert 100 = Enum.count(actual_game.turns)
  end

  test "add too many players", %{game_name: game_name} do
    GameServer.add_player(game_name, "V")
    GameServer.add_player(game_name, "W")
    GameServer.add_player(game_name, "X")
    GameServer.add_player(game_name, "Y")
    GameServer.add_player(game_name, "Z")
    assert {:error, "Already at max players"} == GameServer.add_player(game_name, "!!")
  end

  test "start game", %{game_name: game_name} do
    GameServer.add_player(game_name, "W")
    GameServer.add_player(game_name, "X")
    GameServer.add_player(game_name, "Y")
    GameServer.add_player(game_name, "Z")

    %Game{day: day, score: score, players: players} = GameServer.start_game(game_name)
    player = Enum.at(players, 1)
    assert 1 == day
    assert 0 == score
    assert :act == player.state
  end

  test "set conwip", %{game_name: game_name} do
    game = GameServer.set_wip(game_name, :agg, 2)
    assert {:agg, 2} == game.wip_limits
  end

  test "set stdwip", %{game_name: game_name} do
    game = GameServer.set_wip(game_name, :std, 2)
    assert {:std, 2} == game.wip_limits
  end

  test "set nowip", %{game_name: game_name} do
    game = GameServer.set_wip(game_name, :std, 2)
    assert {:std, 2} == game.wip_limits
    game2 = GameServer.set_wip(game_name, :none, 1)
    assert {:none, 0} == game2.wip_limits
  end

  # test "player moves", %{game_name: game_name} do
  #   GameServer.add_player(game_name)
  #   game1 = GameServer.start_game(game_name)

  #   assert 1 == game1.day
  #   IO.puts("After start - day: #{inspect game1.day} player: #{inspect Enum.at(game1.players,0)}")
  #   game2 = GameServer.move(game_name, :start, 0, 0)
  #   IO.puts("After move  - day: #{inspect game2.day} player: #{inspect Enum.at(game2.players,0)}")
  #   case (Game.get_player(game2, 0)).machine do
  #     :red -> assert 2 == game2.day
  #     :black -> assert 1 == game2.day
  #   end
  # end
end
