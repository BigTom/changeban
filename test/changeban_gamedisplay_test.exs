defmodule ChangebanGameDisplayTest do
  use ExUnit.Case
  doctest Changeban.GameDisplay
  alias Changeban.GameDisplay
  alias Changeban.Game

  test "partition_items_by_state_n_type" do
    items = GameDisplay.partition_items_by_state_and_type(Game.new())
    assert 8 == Enum.count(Map.get(items, 0))
    assert 8 == Enum.count(Map.get(items, 1))
  end
end
