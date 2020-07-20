defmodule Changeban.Player do
  @moduledoc """
    Tracks players information and turn state

    :id must be an integer from 0-4 for an active player
    :turn_type must be :red or :black
    :state must be :act, :help or :cancel

  """
  alias Changeban.Player

  defstruct id: nil, turn_type: nil, state: nil

  def new(id) do
     %Player{id: id}
  end
end
