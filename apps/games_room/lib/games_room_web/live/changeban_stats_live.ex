defmodule GamesRoomWeb.ChangebanStatsLive do
  require Logger
  use GamesRoomWeb, :live_view

  alias Phoenix.{PubSub, LiveView}
  alias Contex.{BarChart, Plot, Dataset}
  alias Changeban.{Game, GameServer}

  @impl true
  def mount(%{"game_name" => game_name}, _session, socket) do
    if !GameServer.game_exists?(game_name) do
      msg = "Game #{game_name} does not exist, it may have timed out after a period of inactivity"
      Logger.info(msg)
      redirect_to_join(socket, msg)
    else
      history = GameServer.history(game_name)

      IO.puts("history #{inspect(history)}")

      {line_cfd, bar_cfd} = generate_charts(game_name)

      PubSub.subscribe(GamesRoom.PubSub, game_name)

      {:ok,
      socket
      |> assign(game_name: game_name)
      |> assign(bar_cfd: bar_cfd)
      |> push_event("line_cfd", line_cfd)}
    end
  end

  def redirect_to_join(socket, msg) do
    {:ok,
     socket
     |> put_flash(:error, msg)
     |> LiveView.redirect(to: "/join", replace: true)}
  end

  # @impl true
  # def handle_info(:change, %{assigns: assigns} = socket) do
  #   Logger.debug("Change notify: #{inspect(assigns.game_name)} stats view")

  #   history = GameServer.history(assigns.game_name)
  #   cfd = generate_cfd(history)

  #   {:noreply, assign(socket, cfd: cfd)}
  # end

  @impl true
  def handle_info(:change, %{assigns: %{game_name: game_name}} = socket) do
    Logger.debug("Change notify: #{inspect(game_name)} stats view")

    {line_cfd, bar_cfd} = generate_charts(game_name)

    IO.puts("send #{inspect line_cfd}")

    {:noreply,
      socket
      |> assign(bar_cfd: bar_cfd)
      |> push_event("line_cfd", line_cfd)}
  end

  def generate_charts(game_name) do
    history = GameServer.history(game_name)
    turn = Enum.count(history)
    turn_ticks = Enum.map(0..turn, &Integer.to_string/1)

    points = convert_to_state_sequences(history)

    line_cfd = %{x:
      %{"data" => points,
        "headers" => turn_ticks }
    }

    bar_cfd = generate_cfd(history)
    {line_cfd, bar_cfd}
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** CHANGEBAN_STATS_LIVE UNKNOWN-EVENT #{inspect(evt)}")
    {:noreply, socket}
  end

  def generate_cfd(history) do
    dataset = Dataset.new(history, ["CFD" | col_names()])

    IO.puts("dataset: #{inspect(dataset, pretty: true)}")

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
        <div phx-update="ignore" class="w-1/2 mt-4">
          <canvas id="myChart" phx-hook="chart"></canvas>
        </div>
        <div class="w-1/2 mt-4">
          <%= @bar_cfd %>
        </div>
      </div>
    """
  end

  def state_name(id), do: Map.get(Game.states(), id)

  def col_names(), do: for(id <- 8..0, do: state_name(id))

  def convert_to_state_sequences(history) do
    flipped =
      for state_id <- 9..1,
          do:
            for(
              turn <- 0..(Enum.count(history) - 1),
              do: Enum.at(history, turn) |> Enum.at(state_id)
            )

    {active, d} = Enum.split(flipped, 4)

    done = Enum.zip(d) |> Enum.map(&Tuple.to_list/1) |> Enum.map(&Enum.sum/1)
    [_ | turns] = (active ++ [done])
    turns
  end
end
