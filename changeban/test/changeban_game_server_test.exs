defmodule ChangebanGameServerTest do
  use ExUnit.Case, async: false
  # doctest Changeban.GameServer

  alias Changeban.{GameSupervisor, GameServer, Game}

  setup do
    game_name = "#{Enum.random(0..999999)}"

    on_exit fn ->
      IO.puts("exiting game: #{game_name}")
      GameSupervisor.stop_game(game_name)
    end

    IO.puts("starting game: #{game_name}")
    GameSupervisor.start_game(game_name)

    {:ok, game_name: game_name}
  end

  test "add player to game", %{game_name: game_name} do
    {:ok, player_id, game} = GameServer.add_player(game_name)
    assert 0 == player_id
    assert 1 = Game.player_count(game)
  end

  test "add too many players", %{game_name: game_name} do
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    assert {:error, "Already at max players"} == GameServer.add_player(game_name)
  end

  test "start game", %{game_name: game_name} do
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)
    GameServer.add_player(game_name)

    %Game{turn: turn, score: score, players: players} = GameServer.start_game(game_name)
    player = Enum.at(players, 1)
    assert 1 == turn
    assert 0 == score
    assert :act == player.state
  end

  # test "player moves", %{game_name: game_name} do
  #   GameServer.add_player(game_name)
  #   game1 = GameServer.start_game(game_name)

  #   assert 1 == game1.turn
  #   IO.puts("After start - turn: #{inspect game1.turn} player: #{inspect Enum.at(game1.players,0)}")
  #   game2 = GameServer.move(game_name, :start, 0, 0)
  #   IO.puts("After move  - turn: #{inspect game2.turn} player: #{inspect Enum.at(game2.players,0)}")
  #   case (Game.get_player(game2, 0)).machine do
  #     :red -> assert 2 == game2.turn
  #     :black -> assert 1 == game2.turn
  #   end
  # end
end
