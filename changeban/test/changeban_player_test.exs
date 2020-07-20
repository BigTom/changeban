defmodule ChangebanPlayerTest do
  use ExUnit.Case
  doctest Changeban.Player

  alias Changeban.Player

  test "New item" do
    assert %Player{id: 0, turn_type: nil, state: nil} == Player.new(0)
  end
end
