defmodule GamesRoomWeb.ChangebanStatsLive do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Contex.{BarChart, Plot, Chart, Dataset, CategoryColourScale}

  def mount(_params, _session, socket) do
    # data = [["1", 10], ["2", 9], ["3", 8], ["4", 7]]
    # dataset = Dataset.new(data)
    dataset = make_test_data()

    plot_content =
      BarChart.new(dataset)
      |> BarChart.set_val_col_names(["A", "B", "C", "D"])
      |> BarChart.orientation(:vertical)
      |> BarChart.type(:stacked)
      |> BarChart.data_labels(false)
      |> BarChart.padding(0)
      |> BarChart.colours(:pastel1)
      # |> BarChart.colours(["ff9838", "fdae53", "fbc26f", "fad48e", "fbe5af", "fff5d1"])

    column = Plot.new(400, 200, plot_content) |> Plot.to_svg

    {:ok, assign(socket, column: column)}
  end

  def chart_options() do
    %{
      categories: 50,           # turns
      series: 3,                # states
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

  def render(assigns) do
    ~L"""
      <div>
        <%= @column %>
      </div>
    """
  end

  def make_test_data() do
    turns = 33
    states = 4

    data =
      1..turns
      |> Enum.map(fn turn ->
        turn_data = for _ <- 1..states do
          Enum.random(1..10)
        end
        ["#{turn}" | turn_data]
      end)

    turn_cols = ["A", "B", "C", "D"]

    dataset = Dataset.new(data, ["State" | turn_cols])

    IO.puts("#{inspect dataset}")
    dataset
  end
end


  # def handle_event("chart_options_changed", %{}=params, socket) do
  #   socket =
  #     socket
  #     |> update_chart_options_from_params(params)
  #     |> make_test_data()

  #   {:noreply, socket}
  # end

  # def handle_event("chart1_bar_clicked", %{"category" => category, "series" => series, "value" => value}=_params, socket) do
  #   bar_clicked = "You clicked: #{category} / #{series} with value #{value}"
  #   selected_bar = %{category: category, series: series}

  #   socket = assign(socket, bar_clicked: bar_clicked, selected_bar: selected_bar)

  #   {:noreply, socket}
  # end

  # def basic_plot(test_data, chart_options, selected_bar) do
  #   plot_content = BarChart.new(test_data)
  #     |> BarChart.set_val_col_names(chart_options.series_columns)
  #     |> BarChart.type(chart_options.type)
  #     |> BarChart.data_labels(chart_options.show_data_labels == "yes")
  #     |> BarChart.orientation(chart_options.orientation)
  #     |> BarChart.event_handler("chart1_bar_clicked")
  #     |> BarChart.colours(lookup_colours(chart_options.colour_scheme))


  #   plot_content = case chart_options.show_selected do
  #     "yes" -> BarChart.select_item(plot_content, selected_bar)
  #     _ -> plot_content
  #   end

  #   options = case chart_options.show_legend do
  #     "yes" -> %{legend_setting: :legend_right}
  #     _ -> %{}
  #   end

  #   {x_label, y_label} = case chart_options.show_axislabels do
  #     "yes" -> {"x-axis", "y-axis"}
  #     _ -> {nil, nil}
  #   end

  #   plot = Plot.new(500, 400, plot_content)
  #     |> Plot.titles(chart_options.title, chart_options.subtitle)
  #     |> Plot.axis_labels(x_label, y_label)
  #     |> Plot.plot_options(options)

  #   Plot.to_svg(plot)
  # end

  # def plot_code(chart_options, selected_bar) do

  #   select_item_line = case chart_options.show_selected do
  #     "yes" ->
  #       if is_nil(selected_bar) do
  #         ~s|\|> BarChart.select_item(nil)|
  #       else
  #         ~s|\|> BarChart.select_item(%{category: "#{selected_bar.category}", series: "#{selected_bar.series}"})|
  #       end
  #     _ -> ""
  #   end

  #   options = case chart_options.show_legend do
  #     "yes" -> "%{legend_setting: :legend_right}"
  #     _ -> "%{}"
  #   end

  #   {x_label, y_label} = case chart_options.show_axislabels do
  #     "yes" -> {"x-axis", "y_axis"}
  #     _ -> {nil, nil}
  #   end

  #   code = ~s"""
  #   plot_content = BarChart.new(test_data)
  #     |> BarChart.set_val_col_names(#{inspect(chart_options.series_columns)})
  #     |> BarChart.type(#{inspect(chart_options.type)})
  #     |> BarChart.data_labels(#{inspect((chart_options.show_data_labels == "yes"))})
  #     |> BarChart.orientation(#{inspect(chart_options.orientation)})
  #     |> BarChart.event_handler("chart1_bar_clicked")
  #     |> BarChart.colours(#{inspect(lookup_colours(chart_options.colour_scheme))})
  #     #{select_item_line}
  #   plot = Plot.new(500, 400, plot_content)
  #     |> Plot.titles("#{chart_options.title}", "#{chart_options.subtitle}")
  #     |> Plot.axis_labels("#{x_label}", "#{y_label}")
  #     |> Plot.plot_options(#{options})
  #   """

  #   {:safe, Makeup.highlight(code)}
  # end

  # defp make_test_data(socket) do
  #   options = socket.assigns.chart_options
  #   series = options.series
  #   categories = options.categories

  #   data = 1..categories
  #   |> Enum.map(fn cat ->
  #     series_data = for _ <- 1..series do
  #       random_within_range(10.0, 100.0)
  #     end
  #     ["Category #{cat}" | series_data]
  #   end)

  #   series_cols = for i <- 1..series do
  #     "Series #{i}"
  #   end

  #   test_data = Dataset.new(data, ["Category" | series_cols])

  #   options = Map.put(options, :series_columns, series_cols)

  #   assign(socket, test_data: test_data, chart_options: options)
  # end

  # defp random_within_range(min, max) do
  #   diff = max - min
  #   (:rand.uniform() * diff) + min
  # end

  # defp get_code_highlighter_styles() do
  #   style = Makeup.Styles.HTML.StyleMap.friendly_style
  #   css = Makeup.stylesheet(style)
  #   {:safe, css}
  # end
# end
