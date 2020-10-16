defmodule GamesRoomWeb.ChangebanStatsLive do
  require Logger
  use GamesRoomWeb, :live_view

  alias Phoenix.{PubSub}
  alias Contex.{BarChart, Plot, Dataset}
  alias Changeban.{Game, GameServer}

  @impl true
  def mount(%{"game_name" => game_name}, _session, socket) do
    history = GameServer.history(game_name)

    IO.puts("history #{inspect(history)}")

    cfd = generate_cfd(history)
    PubSub.subscribe(GamesRoom.PubSub, game_name)

    {:ok, assign(socket, game_name: game_name, cfd: cfd)}
  end

  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    Logger.debug("Change notify: #{inspect(assigns.game_name)} stats view")

    history = GameServer.history(assigns.game_name)
    cfd = generate_cfd(history)

    {:noreply, assign(socket, cfd: cfd)}
  end

  def generate_cfd(history) do
    dataset = Dataset.new(history, ["CFD" | col_names()])

    plot_content =
      BarChart.new(dataset)
      |> BarChart.set_val_col_names(col_names())
      |> BarChart.orientation(:vertical)
      |> BarChart.type(:stacked)
      |> BarChart.data_labels(false)
      |> BarChart.padding(0)
      |> BarChart.force_value_range({0, 20})
      |> BarChart.colours(colours())

    Plot.new(500, 400, plot_content)
    |> Plot.plot_options(%{legend_setting: :legend_right})
    |> Plot.titles("CFD", "")
    |> Plot.to_svg()
  end

  def chart_options() do
    %{
      # turns
      categories: 50,
      # states
      series: 3,
      type: :stacked,
      orientation: :vertical,
      show_data_labels: "no",
      show_selected: "no",
      show_axislabels: "no",
      title: nil,
      subtitle: nil,
      colour_scheme: "pastel",
      show_legend: "no"
    }
  end

  def colours() do
    [
      "88aabb",
      "88aabb",
      "88aabb",
      "88aabb",
      "88aabb",
      "ddffdd",
      "ffffdd",
      "ffdddd",
      "ffffff"
    ]
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="flex">
      <div class="w-2/3 mt-4">
        <%= @cfd %>
      </div>
    """
  end

  def state_name(id), do: Map.get(Game.states(), id)

  def col_names(), do: for(id <- 8..0, do: state_name(id))
end
