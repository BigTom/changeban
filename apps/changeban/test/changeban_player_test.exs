defmodule ChangebanPlayerTest do
  use ExUnit.Case
  doctest Changeban.Player

  alias Changeban.{Game, Player}

  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  test "New item" do
    assert %Player{id: 0, machine: nil, state: nil, options: Player.empty_options, initials: "AA"} == Player.new(0, "AA")
  end

  test "calculate black turn player block options" do
    player = %Player{id: 0, machine: :black, state: :new, options: Map.new}
    items =
      [%Changeban.Item{blocked: true, id: 0, owner: 1, state: 2, type: :task},
       %Changeban.Item{blocked: false, id: 1, owner: 0, state: 1, type: :task}]

    expected_options = %{Player.empty_options() | block: [1]}
    expected_player = %Player{id: 0, machine: :black, state: :act, options: expected_options}
    assert expected_player == Player.calculate_player_options(items, player, @no_wip_limits)
  end

  test "player_red_move_options_at_start" do
    items = Game.initial_items(16)
    player = Player.new(0, "X")
    expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
    expected_response = %Changeban.Player{id: 0, machine: nil, options: expected_options, past: nil, state: :act, initials: "X"}

    assert expected_response == Player.red_options(items, player, @no_wip_limits)
  end

  test "player_black_move_options_at_start" do
    items = Game.initial_items(16)
    player = %Player{id: 0, machine: :black, state: :new, options: Player.empty_options()}
    expected_options = %{Player.empty_options() | start: Enum.to_list(0..15)}
    expected_response = %Player{id: 0, machine: :black, options: expected_options, past: nil, state: :act}

    assert expected_response == Player.black_options(items, player, @no_wip_limits)
  end

  test "player black moves in early game" do
    player = %Player{id: 1, machine: :black, state: :act, options: Player.empty_options()}
    items = [
      %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
      %Changeban.Item{blocked: false, id: 1, owner: 0, state: 1, type: :change},
      %Changeban.Item{blocked: false, id: 2, owner: 1, state: 1, type: :task}
    ]
    expected_options = %{Player.empty_options() | block: [2]}
    expected_response = %{ player | options: expected_options}

    assert expected_response == Player.black_options(items, player, @no_wip_limits)
  end

  test "player_red_move_options_all blocked" do
    items = [
      %Changeban.Item{blocked: true, id: 0, owner: 0, state: 1, type: :task},
      %Changeban.Item{blocked: true, id: 1, owner: 0, state: 1, type: :change},
      %Changeban.Item{blocked: true, id: 2, owner: 0, state: 1, type: :task}
    ]

    player = %{Player.new(0, "X") | machine: :red}
    expected_options = %{Player.empty_options() | unblock: [0,1,2]}
    expected_response = %Changeban.Player{id: 0, machine: :red, options: expected_options, past: nil, state: :act, initials: "X"}

    assert expected_response == Player.red_options(items, player, @no_wip_limits)
  end

  # defp add_player(game, initials) do
  #   {:ok, _, game} = Game.add_player(game, initials)
  #   game
  # end
end
