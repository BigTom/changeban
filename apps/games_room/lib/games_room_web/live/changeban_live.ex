defmodule GamesRoomWeb.ChangebanLive do
  require Logger
  use GamesRoomWeb, :live_view

  # use Phoenix.LiveView
  alias Phoenix.PubSub
  alias GamesRoom.Presence
  alias Changeban.{GameServer, GameSupervisor, Player, Item}

  @game_topic "game"

  @doc """
    creates user presence in game
    If there is a game_name
     in the socket - carry on
    If there is no game_name
     create a game


     If game in params then
      find game
      add player
     If no game in params
      Create Game
      add player
  """
  @impl true
  def mount(%{"game_name" => game_name}, _session, socket) do
    Logger.info("In GamesRoomWeb.ChangebanLive.mount - game_name: #{inspect game_name} -------")

    PubSub.subscribe(GamesRoom.PubSub, @game_topic)
    Presence.track(self(), game_name, socket.id, %{player_id: nil})
    GamesRoomWeb.Endpoint.subscribe(game_name)

    initial_present = Presence.list(game_name) |> map_size

    Logger.info("Before: Mounted Socket Assigns: #{inspect socket.assigns}")

    {items, players, turn, score, state} = GameServer.view(game_name)

    new_socket = assign(socket,
        game_name: game_name,
        items: items,
        players: players,
        turn: turn,
        score: score,
        state: state,
        present: initial_present,
        player: nil,
        player_id: nil,
        username: nil)

    Logger.info("INITIAL #{turn} No player yet")

    {:ok, new_socket }
  end

  @doc """
    Invoked when there is no game_name in the url.
    Creates a game and adds the game_name to teh socket then passes on to the
    main mount function
  """
  @impl true
  def mount(params, session, socket) do
    Logger.info("In GamesRoomWeb.ChangebanLive.mount - no params")
    Logger.info("params: #{inspect params}  ---------- NO GAME_NAME_SUPPLIED")
    game_name = gen_game_name()
    GameSupervisor.create_game(game_name)
    mount(%{"game_name" => game_name}, session, socket)
  end

  @doc """
  Game changes are notified with a simple flag.
  Each Liveview in the game will then check the game state
  """
  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    Logger.info("PubSub notify: #{assigns.game_name}")
    {:noreply, update_only(socket)}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}} = evt,
        %{assigns: %{present: present}} = socket
      ) do
    Logger.info("Presence update: #{inspect evt}")
    new_present = present + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :present, new_present)}
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** UNKNOWN-EVENT ****")
    Logger.warn("Info -----: #{inspect evt} :---")
    Logger.warn("Socket ---: #{inspect socket} :---")
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "add_player",
        %{"initials" => initials, "game_name" => ""} = params,
        %{assigns: assigns} = socket) do
    Logger.info("add_player to new game params: #{inspect params}")
    {:ok, id, player} = GameServer.add_player(socket.assigns.game_name, initials)
    Logger.info("Updating presence metadata: #{inspect %{player_id: id}}")
    Presence.update(self(), assigns.game_name, socket.id, %{player_id: id})
    {:noreply, update_and_notify(assign(socket, player: player, player_id: id, username: initials))}
  end

  @impl true
  def handle_event(
        "add_player",
        %{"initials" => initials, "game_name" => game_name} = params,
        socket) do
    Logger.info("add_player to existing game params: #{inspect params}")
    {:ok, id, player} = GameServer.add_player(game_name, initials)
    Logger.info("Updating presence metadata: #{inspect %{player_id: id}}")
    Presence.update(self(), game_name, socket.id, %{player_id: id})
    {:noreply, update_and_notify(assign(socket, game_name: game_name, player: player, player_id: id, username: initials))}
  end

  @impl true
  def handle_event("start", _, socket) do
    GameServer.start_game(socket.assigns.game_name)
    {:noreply, update_and_notify(socket)}
  end

  @impl true
  def handle_event("move", %{"id" => id, "type" => type}, socket) do
    type_atom = String.to_atom(type)
    Logger.info("MOVE: item: #{id} act: #{type_atom}")
    GameServer.move(socket.assigns.game_name, type_atom, String.to_integer(id), socket.assigns.player_id)
    {:noreply, update_and_notify(socket)}
  end

  defp prep_assigns(socket, items, players, turn, score, state) do
    player = if socket.assigns.player_id do
      player = Enum.at(players,socket.assigns.player_id)
      Logger.info("ASSIGNS name: #{socket.assigns.username} turn: #{turn} game_state: #{state} turn_type: #{player.machine} state: #{player.state} past: #{inspect player.past} options: #{inspect player.options} ")
      player
    else
      Logger.info("ASSIGNS name: #{socket.assigns.username} turn: #{turn} NO PLAYER YET")
      nil
    end
    assign(socket,
      items: items,
      players: players,
      player: player,
      turn: turn,
      score: score,
      state: state)
  end

  defp update_and_notify(socket) do
    {items, players, turn, score, state} = GameServer.view(socket.assigns.game_name)
    PubSub.broadcast(GamesRoom.PubSub, @game_topic, :change)
    prep_assigns(socket, items, players, turn, score, state)
  end

  defp update_only(socket) do
    {items, players, turn, score, state} = GameServer.view(socket.assigns.game_name)
    prep_assigns(socket, items, players, turn, score, state)
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="relative">
      <%= if @username == nil do %>
        <%= render_join_view(assigns) %>
      <% end %>
      <div class="z-20">
        <div class="flex justify-between pt-4">
          <%= turn_display(%{turn: @turn, player: @player}) %>
          <%= render_state_instructions(assigns) %>
          <%= render_score_display(assigns) %>
        </div>
        <%= render_game_grid assigns %>
      </div>
      <p class="class="text-gray-900 text-base text-center border-2 border-gray-500>
        Game name: <%= @game_name %> Player Count: <%= Enum.count(@players) %>
        Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
      </p>
    </div>
    """
  end



  def render_join_view(assigns) do
    ~L"""
      <div class="absolute z-40 flex flex-col items-center justify-center
                  bg-gray-600 bg-opacity-50
                  w-full h-full
                  font-sans">
        <div class="bg-gray-200 rounded shadow p-8 m-4 max-w-xs max-h-full text-center overflow-y-scroll">
        <p class="text-left">Please enter an initial with which to identify your items</p>
        <form phx-submit="add_player">
            <div class="text-left flex">
              <label class="w-2/3 text-gray-700 text-sm font-bold mb-2 px-2" for="initials">Initials (1 or 2 letters):</label>
              <input class="w-1/3 shadow appearance-none border rounded py-2 px-3
                            text-gray-700
                            focus:outline-none focus:shadow-outline" name="initials" id="initials"
                            type="text" maxlength="2">
            </div>
            <div class="py-2 flex">
              <label class="w-2/3 text-gray-700 text-sm font-bold mb-2 px-2" for="game_name">Game Name (or blank to start a new game):</label>
              <input class="w-1/3 shadow appearance-none border rounded py-2 px-3
                            text-gray-700
                            focus:outline-none focus:shadow-outline" name="game_name" id="game_name" type="text">
            </div>
            <div class="flex items-center justify-between">
              <button type="submit" class="bg-gray-500 hover:bg-blue-700 text-white font-bold py-2 px-4
                                           rounded focus:outline-none focus:shadow-outline" >
                Enter
              </button>
            </div>
          </form>
        </div>
      </div>
  """
  end

  def render_game_grid(assigns) do
    ~L"""
    <div class="grid grid-cols-cb grid-rows-cb my-4 container border border-gray-800 text-center">
      <%= headers(assigns) %>
      <div class="col-start-1 row-start-3 row-span-5 border border-gray-800">
      <%= active_items(assigns, 0) %>
      </div>
      <div class="col-start-2 row-start-3 row-span-5 border border-gray-800">
        <%= active_items(assigns, 1) %>
      </div>
      <div class="col-start-3 row-start-3 row-span-5 border border-gray-800">
        <%= active_items(assigns, 2) %>
      </div>
      <div class="col-start-4 row-start-3 row-span-5 border border-gray-800">
        <%= active_items(assigns, 3) %>
      </div>

      <div class="col-start-5 col-span-4 row-start-4 border border-gray-800">
        <%= completed_items(assigns, 4) %>
      </div>

      <div class="col-start-5 row-start-7 row-span-2 border border-gray-800">
        <%= completed_items(assigns, 5) %>
      </div>
      <div class="col-start-6 row-start-7 row-span-2 border border-gray-800">
        <%= completed_items(assigns, 6) %>
      </div>
      <div class="col-start-7 row-start-7 row-span-2 border border-gray-800">
        <%= completed_items(assigns, 7) %>
      </div>
      <div class="col-start-8 row-start-7 row-span-2 border border-gray-800">
        <%= completed_items(assigns, 8) %>
      </div>
    </div>
    """
  end

  def render_state_instructions(assigns) do
    Logger.info("GAME STATE: #{inspect assigns.state}")
    case assigns.state do
      :setup -> render_setup_instructions(assigns)
      :running -> render_turn_instructions(assigns)
      :done -> render_simulation_over(assigns)
    end
  end

  def render_setup_instructions(assigns) do
    ~L"""
      <div class="flex-grow flex flex-col border-2 border-green-600 mx-4 rounded-md
                  text-green-600 items-center text-center">
        <p>When all players have joined press "START SIMULATION"</p>
        <button class="border-2 border-gray-800 rounded-md bg-green-400 w-1/2"
                phx-click="start">START SIMULATION</button>
      </div>
    """
  end

  def render_simulation_over(assigns) do
    ~L"""
      <div class="flex-grow border-2 border-green-600 mx-4 rounded-md
                  text-green-600 text-2xl text-center">
        SIMULATION COMPLETED
      </div>
    """
  end

  def render_specific_instructions(%Player{} = player) do
    cond do
      player.state == :done -> render_done_instructions(player)
      helping?(player.options) -> render_help_instructions(player)
      rejecting?(player.options) -> render_reject_instructions(player)
      true ->
        case player.machine do
          :black -> render_black_instructions(player)
          :red -> render_red_instructions(player)
        end
    end
  end

  def render_turn_instructions(assigns) do
    ~L"""
    <div class="flex-grow border-2 border-gray-700 rounded-md text-sm text-center">
      <p class="text-base font-bold">Instructions</p>
      <%= render_specific_instructions(assigns.player) %>
    </div>
    """
  end

  def render_done_instructions(assigns) do
    ~L"""
    <p class="text-gray-600">You are waiting for the other players to go</p>
    """
  end

  def render_help_instructions(assigns) do
    ~L"""
    <p>You can help someone!  Unblock or move someone else's item</p>
    """
  end

  def render_reject_instructions(assigns) do
    ~L"""
    <p>Now you have accepted an item you can reject any item on the board</p>
    <p>Discuss with the others which one to reject</p>
    """
  end

  def render_black_instructions(assigns) do
    ~L"""
    <%=cond do %>
      <% ! Enum.empty?(@options.block) -> %>
        <p>You must block one unblocked item</p>
      <% ! Enum.empty?(@options.start) -> %>
        <p>You must start one new item</p>
    <% end %>
    """
  end

  def render_red_instructions(%{options: options} = assigns) do
    add_move = fn list -> if (not Enum.empty?(options.move)), do: ["move one of your unblocked items one column right" | list], else: list end
    add_unbk = fn list -> if (not Enum.empty?(options.unblock)), do: ["unblock one of your blocked items" | list], else: list end
    add_strt = fn list -> if (not Enum.empty?(options.start)), do: ["start one new item" | list], else: list end

    words = [] |> add_strt.() |> add_unbk.() |> add_move.()

    text = case Enum.count(words) do
      1 -> "<p>You must " <> List.first(words) <> "</p>"
      _ -> "<p>You must either " <> Enum.join(words, "</p><p>or ") <> "</p>"
    end

    ~L"""
      <%= raw text %>
    """
  end

  def helping?(%{hlp_mv: hlp_mv, hlp_unblk: hlp_unblk}) do
    not (Enum.empty?(hlp_mv) && Enum.empty?(hlp_unblk))
  end

  def rejecting?(%{reject: reject}) do
    not Enum.empty?(reject)
  end

  def turn_display(%{player: player, turn: turn}) do
    cond do
      player == nil || turn == 0 ->
        render_turn_display(%{font_color: "gray-400", nr: turn})
      player.machine == :red ->
        render_turn_display(%{font_color: "red-700", nr: turn})
      true ->
        render_turn_display(%{font_color: "black", nr: turn})
    end
  end

  @spec render_turn_display(any) :: Phoenix.LiveView.Rendered.t()
  def render_turn_display(assigns) do
    ~L"""
      <div class="w-1/6 flex flex-col
                  border-2 border-<%= @font_color %> rounded-md
                  text-<%= @font_color %> text-2xl">
        <div class="text-center">Turn:</div>
        <div class="text-center"><%= to_string(:io_lib.format("~2..0B", [@nr])) %></div>
      </div>
    """
  end
  def render_score_display(assigns) do
    ~L"""
      <div class="w-1/6 flex flex-col border-2 border-black rounded-md
                  text-black text-2xl">
        <div class="text-center">Score:</div>
        <div class="text-center"><%= to_string(:io_lib.format("~2..0B", [@score])) %></div>
      </div>
    """
  end


  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked}, _players, nil) do
    %{id: item_id, type: type, blocked: blocked, player_id: nil, initials: "  ", options: []}
  end

  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked, owner: owner_id}, players, %Player{id: player_id, options: options}) do
    item_initials =
      if owner_id != nil do
        owning_player = (Enum.at(players, owner_id))
        if owning_player != nil do
          owning_player.initials
        else
          "  "
        end
      else
        "  "
      end
    new_assigns
        = %{id: item_id,
            mine: (owner_id == player_id),
            type: type,
            blocked: blocked,
            initials: item_initials,
            options: options}
    # Logger.debug("au_data: #{inspect new_assigns}")
    new_assigns
  end

  def render_active_item(%{id: item_id, options: options} = assigns) do
    case Enum.find(options, fn ({_option_type, item_list}) ->
                                  (Enum.find(item_list, &(&1 == item_id)) != nil) end) do
      {type, _} ->  render_actionable_item(assigns, type)
      _ -> render_passive_item(assigns)
    end
  end

  def render_actionable_item(assigns, type) do
    ~L"""
    <%= if @type == :task do %>
      <div class="border-2 shadow bg-green-500 border-green-800 w-8 px-1 py-3 m-1
                  focus:outline-none focus:shadow-outline"
          phx-click="move"
          phx-value-type="<%= type %>"
          phx-value-id="<%= @id %>">
          <%= render_initials(assigns) %>
      </div>
    <% else %>
      <div class="border-2 shadow bg-yellow-300 border-yellow-800 w-8 px-1 py-3 m-1
                  focus:outline-none focus:shadow-outline"
          phx-click="move"
          phx-value-type="<%= type %>"
          phx-value-id="<%= @id %>">
          <%= render_initials(assigns) %>
      </div>
    <% end %>
    """
  end

  def render_passive_item(assigns) do
    ~L"""
    <%= if @type == :task do %>
      <div class="border-2 bg-green-500 border-green-500 w-8 px-1 py-3 m-1">
        <%= render_initials(assigns) %>
      </div>
    <% else %>
      <div class="border-2 bg-yellow-300 border-yellow-300 w-8 px-1 py-3 m-1">
        <%= render_initials(assigns) %>
      </div>
    <% end %>
    """
  end

  def render_initials(assigns) do
    color = case assigns.type do
        :task -> "text-green-500"
        _ -> "text-yellow-300"
      end
    case assigns.initials do
      "  " -> ~L"""
                <div class="<%= color %>">XX</div>
              """
      _ ->  ~L"""
              <div <%= if @blocked do %> class="font-black" <% end %> >
                <%= @initials %>
              </div>
            """
    end
  end

  def render_finished_item(assigns) do
    # Logger.info("render_item: #{inspect assigns}")
    ~L"""
      <%= if @type == :task do %>
        <div class="border-2 bg-green-500 border-green-800 w-4 px-1 py-3 m-1"></div>
      <% else %>
        <div class="border-2 bg-yellow-300 border-yellow-800 w-4 px-1 py-3 m-1"></div>
      <% end %>
    """
  end

  @doc """
  Finds the items for the given state id then iterates over them and passes each to
  render_active_item/1
  """
  def active_items(assigns, state) do
    ~L"""
      <div class="flex flex-wrap">
        <%= for item <- Map.get(assigns.items, state, []) do %>
          <%= collect_item_data(item, assigns.players, @player) |> render_active_item() %>
        <% end %>
      </div>
    """
  end

  def completed_items(assigns, state) do
    ~L"""
    <div class="flex flex-wrap">
      <%= for item <- Map.get(assigns.items, state, []) do %>
        <%= render_finished_item(item) %>
      <% end %>
    </div>
    """
  end

  def headers(assigns) do
    ~L"""
    <div class="col-start-1 row-start-1 row-span-2 border border-gray-800">Agree Urgency</div>
    <div class="col-start-2 col-span-3 row-start-1 border border-gray-800 py-3">In progress</div>
    <div class="col-start-5 col-span-4 row-start-1 row-span-2 border border-gray-800">Complete</div>
    <div class="col-start-2 row-start-2 border border-gray-800">Negotiate Change</div>
    <div class="col-start-3 row-start-2 border border-gray-800">Validate Adoption</div>
    <div class="col-start-4 row-start-2 border border-gray-800">Verify Performance</div>

    <div class="col-start-5 col-span-4 row-start-3 border border-gray-800">Accepted</div>

    <div class="col-start-5 col-span-4 row-start-5 border border-gray-800">Rejected</div>
    <div class="col-start-5 row-start-6 border border-gray-800">AU</div>
    <div class="col-start-6 row-start-6 border border-gray-800">NC</div>
    <div class="col-start-7 row-start-6 border border-gray-800">VA</div>
    <div class="col-start-8 row-start-6 border border-gray-800">VP</div>
    """
  end

  defp gen_game_name() do
    chars = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789"
    end_index = String.length(chars) - 1
    List.to_string(for _n <- 0..5, do: String.at(chars, Enum.random(0..end_index)))
  end
end
