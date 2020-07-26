defmodule ChangebanGameServerTest do
  use ExUnit.Case, async: true
  # doctest Changeban.GameServer

  alias Changeban.{GameSupervisor, GameServer, Player}

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
    assert 0 == GameServer.add_player(game_name)
  end
end
