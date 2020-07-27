defmodule ChangebanPlayerTest do
  use ExUnit.Case
  doctest Changeban.Player

  alias Changeban.{Game, Player}

  test "New item" do
    assert %Player{id: 0, machine: nil, state: nil, options: nil} == Player.new(0)
  end

  test "calculate black turn player block options" do
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    items =
      [%Changeban.Item{blocked: true, id: 0, owner: 1, state: 2, type: :task},
       %Changeban.Item{blocked: false, id: 1, owner: 0, state: 1, type: :task}]

    expected_player = %Player{id: 0, machine: :black, state: :act, options: [block: [1], start: []]}
    assert expected_player == Player.calculate_player_options(items, player)
  end

  test "player_red_move_options_at_start" do
    items = Game.initial_items()
    player = Player.new(0)
    expected_response = %Changeban.Player{id: 0, machine: nil, options: [move: [], unblock: [], start: Enum.to_list(0..15)], past: nil, state: :act}

    assert expected_response == Player.red_options(items, player)
  end

  test "player_black_move_options_at_start" do
    items = Game.initial_items()
    player = %Player{id: 0, machine: :black, state: :new, options: nil}
    expected_response = %Player{id: 0, machine: :black, options: [block: [], start: Enum.to_list(0..15)], past: nil, state: :act}

    assert expected_response == Player.black_options(items, player)
  end
end
