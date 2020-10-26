defmodule Changeban.ItemHistory do
  alias Changeban.ItemHistory

  defstruct start: nil, done: nil, blocked: []

  def new(), do: %ItemHistory{}

  def start(history, turn), do: %{history | start: turn}

  # move has a special case when it completes
  def move(history, state, turn) when state >= 4, do: %{history | done: turn}
  def move(history, _state, _turn), do: history

  def reject(history, _state, turn) when is_nil(history.start),
    do: %{history | start: turn, done: turn}

  def reject(history, _state, turn), do: %{history | done: turn}

  def block(history, turn), do: toggle_block(history, turn)
  def unblock(history, turn), do: toggle_block(history, turn)

  def toggle_block(%ItemHistory{blocked: blocked} = history, turn) do
    %{history | blocked: [turn | blocked]}
  end

  def blocked_time(%ItemHistory{blocked: blocked}, turn) do
    if rem(Enum.count(blocked),2) == 1 do
      [turn | blocked]
    else
      blocked
    end
    |> Enum.chunk_every(2)
    |> Enum.map(fn pair -> List.first(pair) - List.last(pair) end)
    |> Enum.sum
  end

  def block_count(%ItemHistory{blocked: blocked}), do: div(Enum.count(blocked) + 1, 2)

  def age(%ItemHistory{start: start}, _turn) when is_nil(start), do: 0
  def age(%ItemHistory{start: start, done: done}, turn) do
    case done do
      nil -> turn - start
      _ -> done - start
    end
  end

  def efficency(%ItemHistory{done: done}) when is_nil(done), do: 0
  def efficency(%ItemHistory{done: done} = history) do
    age = ItemHistory.age(history, done)
    blocked = ItemHistory.blocked_time(history, done)
    case age do
      0 -> 1
      _ -> (age - blocked) / age
    end
  end
end
