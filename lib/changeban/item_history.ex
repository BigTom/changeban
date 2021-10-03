defmodule Changeban.ItemHistory do
  @moduledoc """
  Structure and functions to manage the history of a work item
  """

  alias Changeban.ItemHistory

  defstruct start: nil, done: nil, blocked: [], helped: []

  def new(), do: %ItemHistory{}

  def start(history, day), do: %{history | start: day}

  # move has a special case when it completes
  def move(history, state, day) when state >= 4, do: %{history | done: day}
  def move(history, _state, _turn), do: history

  def reject(history, _state, day) do
    case history.start do
      nil -> %{history | start: day, done: day}
      _ -> %{history | done: day}
    end
  end

  def block(history, day), do: toggle_block(history, day)
  def unblock(history, day), do: toggle_block(history, day)

  def help(%ItemHistory{helped: helped} = history, day), do: %{history | helped: [day | helped]}

  def toggle_block(%ItemHistory{blocked: blocked} = history, day) do
    %{history | blocked: [day | blocked]}
  end

  def blocked_time(%ItemHistory{blocked: blocked}, day) do
    if rem(Enum.count(blocked), 2) == 1 do
      [day | blocked]
    else
      blocked
    end
    |> Enum.chunk_every(2)
    |> Enum.map(fn pair -> List.first(pair) - List.last(pair) end)
    |> Enum.sum()
  end

  def block_count(%ItemHistory{blocked: blocked}), do: div(Enum.count(blocked) + 1, 2)
  def help_count(%ItemHistory{helped: helped}), do: Enum.count(helped)

  def age(%ItemHistory{start: start}, _turn) when is_nil(start), do: 0

  def age(%ItemHistory{start: start, done: done}, day) do
    case done do
      nil -> day - start
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
