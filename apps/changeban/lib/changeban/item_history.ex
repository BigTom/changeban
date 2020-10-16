defmodule Changeban.ItemHistory do
  # @au  0 # Agree Urgency
  # Negotiate Change
  @nc 1
  # @va  2 # Validate Adoption
  # @vp  3 # Verify Performance
  # @c 4

  alias Changeban.ItemHistory

  defstruct moves: %{}, blocked: []

  def new(), do: %ItemHistory{}

  def start(%ItemHistory{moves: moves} = history, turn) do
    %{history | moves: Map.put(moves, turn, @nc)}
  end

  # move has a special case when it completes
  def move(%ItemHistory{moves: moves} = history, state, turn) do
    %{history | moves: Map.put(moves, turn, state)}
  end

  # reject has a special case when it rejects an unstarted item
  def reject(%ItemHistory{moves: moves} = history, state, turn) do
    %{history | moves: Map.put(moves, turn, state)}
  end

  def block(history, turn), do: block_change(history, turn, true)
  def unblock(history, turn), do: block_change(history, turn, false)

  def block_change(%ItemHistory{blocked: blocked} = history, turn, state) do
    %{history | blocked: Enum.reverse([{turn, state} | blocked])}
  end
end
