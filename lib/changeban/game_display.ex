defmodule Changeban.GameDisplay do
  @moduledoc """
  Displays a textual representation of a game.

  Note: Only standard colors are supported.
  """

  alias Changeban.{Game, Item}
  alias IO.ANSI

  @doc """
  Prints a textual representation of the game to standard out.
  """
  def display(game) do
    print_headings()
    print_items(game)
  end

  def start_lines(%Game{items: items}) do
    items
  end

  def print_game(game) do
    print_headings()
    print_items(game)
  end

  def print_headings() do
    IO.write("\n")

    IO.puts(
      "|   AU    |         In Progress         |    C    |               Rejected                |"
    )

    IO.puts(
      "|         |   NC    |   V     |   VP    |    C    |   AU    |   NC    |   VA    |   VP    |"
    )

    IO.puts(
      "|  T   C  |  T   C  |  T   C  |  T   C  |  T   C  |  T   C  |  T   C  |  T   C  |  T   C  |"
    )
  end

  def print_items(game) do
    items = partition_items_by_state_and_type(game)
    max = max_items_in_partition(items) - 1
    for line <- 0..max, do: print_line(items, line)
  end

  def print_line(items, n) do
    for(i <- 0..17, do: {rem(i, 2) == 0, Map.get(items, i, []) |> Enum.at(n)})
    |> Enum.map_join(&print_item(elem(&1, 1), elem(&1, 0)))
    |> IO.write()

    IO.puts("|")
  end

  def print_item(nil, true), do: "|    "
  def print_item(nil, false), do: "     "

  def print_item(%Item{type: type, owner: owner, blocked: blocked}, bar) do
    # IO.puts("bar #{bar}")

    [if(bar, do: "", else: " ")]
    |> cons(:black_background)
    |> cons(if blocked, do: [:red, "X"], else: " ")
    |> cons(if owner == nil, do: "  ", else: "#{owner} ")
    |> cons(if type == :task, do: :green_background, else: :yellow_background)
    |> cons(:black)
    |> cons(if bar, do: "| ", else: " ")
    |> cons(:white)
    |> List.flatten()
    |> ANSI.format()
  end

  def cons(list, element), do: [element | list]

  def max_items_in_partition(partitioned_items) do
    partitioned_items |> Map.values() |> Enum.map(&Enum.count(&1)) |> Enum.max()
  end

  def test_game() do
    Game.new()
    |> (&%Game{
          &1
          | items:
              for(
                item <- &1.items,
                do: %Item{item | state: Enum.random(0..8)}
              )
        }).()
    |> (&%Game{
          &1
          | items:
              for(
                item <- &1.items,
                do: %Item{
                  item
                  | blocked: 0 < item.state && item.state < 4 && Enum.random(0..2) == 0
                }
              )
        }).()
    |> (&%Game{
          &1
          | items:
              for(
                item <- &1.items,
                do: %Item{
                  item
                  | owner:
                      if(0 < item.state,
                        do: Enum.random(0..4),
                        else: nil
                      )
                }
              )
        }).()
  end

  @doc """
    Creates a map with a sytnthetic key constructed by taking the state number, doubling
    it and adding one if it is a :change item.  This creates 16 possible keys ordered
    Agree Urgency:tasks to Rejected/VP:changes.
  """
  def partition_items_by_state_and_type(%Game{items: items}) do
    items
    |> Enum.sort_by(& &1.state)
    |> Enum.group_by(&(&1.state * 2 + if(&1.type == :task, do: 0, else: 1)))
  end
end
