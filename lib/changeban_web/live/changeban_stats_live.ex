defmodule ChangebanWeb.ChangebanStatsLive do
  @moduledoc """
  Liveview to show stats for a given game
  """
  require Logger
  use ChangebanWeb, :live_view

  alias Phoenix.{PubSub, LiveView}
  alias Changeban.{GameServer}

  # Stats map
  # %{
  #   turns: [["-", 0, 0, 0, 0, 0, 0, 0, 0, 0]],
  #   ticket_ages: [],
  #   efficiency: 0,
  #   block_count: 0,
  #   day: 0
  # }

  @impl true
  def mount(%{"game_name" => game_name}, _session, socket) do
    Logger.info("stats mount #{game_name}")

    if GameServer.game_exists?(game_name) do
      PubSub.subscribe(Changeban.PubSub, game_name)
      game_stats = GameServer.stats(game_name)

      {:ok,
       socket
       |> assign(game_name: game_name)
       |> assign(game_stats: game_stats)
       |> push_event("chart_data", generate_charts(game_stats))}
    else
      msg = "Game #{game_name} does not exist, it may have timed out after a period of inactivity"
      Logger.info(msg)
      redirect_to_join(socket, msg)
    end
  end

  def redirect_to_join(socket, msg) do
    {:ok,
     socket
     |> put_flash(:error, msg)
     |> LiveView.redirect(to: "/join")}
  end

  @impl true
  def handle_info(:change, %{assigns: %{game_name: game_name}} = socket) do
    Logger.debug("STATS - Change notify: #{inspect(game_name)} stats view")
    game_stats = GameServer.stats(game_name)

    {:noreply,
     socket
     |> assign(game_stats: game_stats)
     |> push_event("chart_data", generate_charts(game_stats))}
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** CHANGEBAN_STATS_LIVE UNKNOWN-EVENT #{inspect(evt)}")
    {:noreply, socket}
  end

  defp generate_charts(stats) do
    turn_ticks = Enum.map(0..stats.day, &Integer.to_string/1)
    points = convert_to_state_sequences(stats.turns)

    %{
      cfd: %{"data" => points, "turns" => turn_ticks},
      age: %{"data" => stats.ticket_ages, "turns" => turn_ticks}
    }
  end

  defp wip_type({type, size}) do
    case type do
      :none -> "No WIP Limits"
      :std -> "Column WIP limit of #{size}"
      :cap -> "Aggregate WIP limit of #{size}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col">
        <div class="text-center text-xl flex justify-around mt-4 border-2">
          <div class="w-1/4 m-2 border-2">Game name: <%= @game_name %></div>
          <div class="w-1/4 m-2 border-2">Player count: <%= @game_stats.players %></div>
          <div class="w-1/4 m-2 border-2"><%= wip_type(@game_stats.wip_limits) %></div>
        </div>

        <div class="flex mt-4 text-xl text-center border-2">
          <div class="w-1/2 relative ">
            <p>Culmulative Flow</p>
            <div id="divCFD" phx-update="ignore">
              <canvas id="myCFD" phx-hook="cfd" aria-label="CFD chart for current state of game" role="img"></canvas>
            </div>
          </div>

          <div class="w-1/2 relative">
            <p>Ticket Age on Completion</p>
            <div id="divAge" phx-update="ignore">
              <canvas id="myAge" phx-hook="age" aria-label="Arrival age chart for current state of game" role="img"></canvas>
            </div>
          </div>
        </div>
        <div class="text-center text-xl flex justify-around mt-4 border-2">
          <div class="w-1/12 m-2 border-2">
            <p>Turns</p>
            <p class="font-black"><%= @game_stats.day %></p>
          </div>
          <div class="w-1/12 m-2 border-2">
            <p>Score</p>
            <p class="font-black"><%= @game_stats.score %></p>
          </div>
          <div class="w-1/12 m-2 border-2">
            <p>Blocked count</p>
            <p class="font-black"><%= @game_stats.block_count %></p>
          </div>
          <div class="w-1/12 m-2 border-2">
            <p>Helped count</p>
            <p class="font-black"><%= @game_stats.help_count %></p>
          </div>
          <div class="w-1/12 m-2 border-2">
            <p>Median Age</p>
            <p class="font-black"><%= @game_stats.median_age %></p>
          </div>
          <div class="w-1/12 m-2 border-2">
          <p>Flow Efficiency</p>
          <p class="font-black"><%= render_percent(@game_stats.efficiency) %></p>
        </div>
        </div>
      </div>
    """
  end

  def render_percent(nr), do: "#{Float.round(nr * 100, 1)}%"

  defp convert_to_state_sequences(history) do
    flipped =
      for state_id <- 9..1,
          do:
            for(
              day <- 0..(Enum.count(history) - 1),
              do: Enum.at(history, day) |> Enum.at(state_id)
            )

    {active, d} = Enum.split(flipped, 4)

    done = Enum.zip(d) |> Enum.map(&Tuple.to_list/1) |> Enum.map(&Enum.sum/1)
    [_ | turns] = active ++ [done]
    turns
  end
end
