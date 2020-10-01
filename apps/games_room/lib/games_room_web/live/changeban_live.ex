defmodule GamesRoomWeb.ChangebanLive do
  require Logger
  use GamesRoomWeb, :live_view

  # use Phoenix.LiveView
  alias Phoenix.{LiveView,PubSub}
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
    Logger.info("MOUNT: game name supplied, not a player yet")
    PubSub.subscribe(GamesRoom.PubSub, @game_topic)
    GamesRoomWeb.Endpoint.subscribe(game_name)

    {items, players, turn, score, state} = GameServer.view(game_name)

    new_socket = assign(socket,
        game_name: game_name,
        items: items,
        players: players,
        turn: turn,
        score: score,
        state: state,
        present: Presence.list(game_name) |> map_size,
        player: nil,
        player_id: nil,
        username: nil)
    Logger.info("MOUNT: #{inspect new_socket.assigns}")
    {:ok, new_socket }
  end

  @doc """
    Invoked when there is no game_name in the url.
    Creates a game and adds the game_name to teh socket then passes on to the
    main mount function
  """
  @impl true
  def mount(_params, _session, socket) do
    Logger.info("MOUNT: no game name, not a player yet")
    PubSub.subscribe(GamesRoom.PubSub, @game_topic)

    new_socket = assign(socket,
      game_name: nil,
      items: nil,
      players: nil,
      turn: nil,
      score: nil,
      state: nil,
      present: 0,
      player: nil,
      player_id: nil,
      username: nil)

    Logger.info("MOUNT: #{inspect new_socket.assigns}")
    {:ok, new_socket}
  end

  @doc """
  Game changes are notified with a simple flag.
  Each Liveview in the game will then check the game state
  """
  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    Logger.info("PubSub notify: #{inspect assigns.game_name}")
    {:noreply, update_only(socket)}
  end

  @impl true
  def handle_info(%{topic: topic}, %{assigns: assigns} = socket) do
    Logger.info("Presence notify: #{Presence.list(topic) |> map_size} logged in as: #{inspect assigns.username}")
    {:noreply, assign(socket, present: Presence.list(topic) |> map_size)}
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
        %{"initials" => initials, "game_name" => ""},
        socket) do
    Logger.warn("add_player event no game name initials: #{inspect initials}")
    game_name = gen_game_name()
    Logger.info("Creating new game #{inspect game_name}")
    GameSupervisor.create_game(game_name)
    {:ok, player_id, player} = GameServer.add_player(game_name, initials)
    GamesRoomWeb.Endpoint.subscribe(game_name)
    Presence.track(self(), game_name, socket.id, %{player_id: player_id})
    {:noreply, update_only(assign(socket, game_name: game_name, player: player, player_id: player_id, username: initials))}
  end

  @impl true
  def handle_event(
        "add_player",
        %{"initials" => initials, "game_name" => supplied_game_name},
        socket) do
    game_name = String.upcase(supplied_game_name)
    Logger.warn("add_player event game_name: #{inspect game_name} initials: #{inspect initials}")
    cond do
      not GameServer.game_exists?(game_name) ->
        Logger.info("Non existant game")
        LiveView.put_flash(socket, :info, "Game #{game_name} does not exist")
        {:noreply, socket}
      GameServer.joinable?(game_name) ->
        Logger.info("Allow player to join game: #{game_name}")
        {:ok, player_id, player} = GameServer.add_player(game_name, initials)
        Presence.track(self(), game_name, socket.id, %{player_id: player_id})
        GamesRoomWeb.Endpoint.subscribe(game_name)
        {:noreply, update_and_notify(assign(socket, game_name: game_name, player: player, player_id: player_id, username: initials))}
      true ->
        Logger.info("Allow player to view game game: #{game_name}")
        Presence.track(self(), game_name, socket.id, %{player_id: ""})
        GamesRoomWeb.Endpoint.subscribe(game_name)
        {:noreply, update_and_notify(assign(socket, game_name: game_name))}
    end
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
      Enum.at(players,socket.assigns.player_id)
    else
      nil
    end
    new_socket = assign(socket,
      items: items,
      players: players,
      player: player,
      turn: turn,
      score: score,
      state: state)
    # Logger.debug("GAME: #{inspect(new_socket.assigns.items, limit: :infinity)}")
    Logger.warn("""
                ASSIGNS:
                game_name: #{inspect new_socket.assigns.game_name}
                present: #{inspect new_socket.assigns.present}
                name: #{inspect new_socket.assigns.username}
                turn: #{inspect new_socket.assigns.turn}
                game_state: #{inspect new_socket.assigns.state}
                """)
    if (not is_nil(new_socket.assigns.player)) do
      Logger.warn("""
                  PLAYER_ASSIGNS
                  turn_type: #{inspect new_socket.assigns.player.machine}
                  state: #{inspect new_socket.assigns.player.state}
                  past: #{inspect new_socket.assigns.player.past}
                  options: #{inspect new_socket.assigns.player.options}
                  """)
    end
    new_socket
  end

  defp update_and_notify(socket) do
    Logger.info("UPDATE-AND-NOTIFY for game: #{socket.assigns.game_name}")
    {items, players, turn, score, state} = GameServer.view(socket.assigns.game_name)
    PubSub.broadcast(GamesRoom.PubSub, @game_topic, :change)
    prep_assigns(socket, items, players, turn, score, state)
  end

  defp update_only(socket) do
    Logger.info("UPDATE-ONLY")
    {items, players, turn, score, state} = GameServer.view(socket.assigns.game_name)
    prep_assigns(socket, items, players, turn, score, state)
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="relative">
      <%= if is_nil(@username) do %>
        <%= cond do %>
          <% is_nil(@game_name) -> %>
            <%= render_join_view(assigns) %>
          <% not GameServer.joinable?(@game_name) -> %>
            <%= render_game_full(assigns) %>
          <% true -> %>
            <%= render_join_view(assigns) %>
        <% end %>
      <% end %>
      <%= if @game_name != nil do %>
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
      <% end %>
    </div>
    """
  end

  def render_game_full(assigns) do
    ~L"""
      <div class="absolute z-40 flex flex-col items-center justify-center
                  w-full h-screen
                  font-sans">
        <div class="bg-white opacity-50 rounded shadow p-8 m-4 max-w-xs max-h-full text-center overflow-y-scroll">
          <p class="text-center">I am sorry, game <%= @game_name %> can no longer be joined.</p>
          <p class="text-center">You can watch the game in progress here.</p>
        </div>
      </div>
  """
  end

  def render_join_view(assigns) do
    ~L"""
      <div class="absolute z-40 flex flex-col items-center justify-center
                  w-full h-screen
                  font-sans">
        <div class="bg-gray-200 rounded shadow p-8 m-4 max-w-md max-h-full text-center overflow-y-scroll">
        <p class="text-left pb-4">Please enter an initial with which to identify your items and the identifier for the game you will be playing</p>
        <form phx-submit="add_player">
            <div class="pt-2 text-left flex">
              <label class="w-2/3 text-gray-700 text-sm font-bold mb-2 px-2" for="initials">Initials (1 or 2 letters):</label>
              <input class="w-1/3 shadow appearance-none border rounded py-2 px-3 focus:outline-none focus:shadow-outline"
                     name="initials" id="initials" type="text" maxlength="2">
            </div>
            <div class="pt-2 text-left flex">
              <label class="w-2/3 text-gray-700 text-sm font-bold mb-2 px-2" for="game_name">Game Name (leave blank to start a new game):</label>
              <input class="w-1/3 shadow appearance-none border rounded py-2 px-3 text-gray-700 uppercase
                            placeholder-gray-300 focus:outline-none focus:shadow-outline"
                     placeholder="<%= @game_name %>" name="game_name" id="game_name" type="text" maxlength="6" value="<%= @game_name %>">
            </div>
            <div class="pt-2 flex items-center justify-between">
              <button type="submit" class="bg-green-300 hover:bg-green-700 text-white font-bold py-2 px-4
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
  def render_specific_instructions(assigns) do
    ~L"""
    <p class="text-gray-600">You are observing this game</p>
    """
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


  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked, owner: owner_id}, players, nil) do
    %{id: item_id,
      mine: false,
      type: type,
      blocked: blocked,
      player_id: nil,
      initials: get_initials(owner_id, players),
      options: [],
      active: false}
  end

  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked, owner: owner_id}, players, %Player{id: player_id, options: options}) do
    %{id: item_id,
      mine: (owner_id == player_id),
      type: type,
      blocked: blocked,
      player_id: player_id,
      initials: get_initials(owner_id, players),
      options: options,
      active: not is_nil(Enum.find(options, fn {_option_type, item_list} -> (Enum.member?(item_list, item_id)) end))
    }
  end

  def get_initials(nil, _players), do: ""
  def get_initials(owner_id, players) when not is_nil(owner_id) do
      case (Enum.at(players, owner_id)) do
        nil -> ""
        owning_player -> owning_player.initials
      end
  end

  def card_scheme(%{type: :task, active: true}), do: "bg-green-500 border-green-800"
  def card_scheme(%{type: :task, active: false}), do: "bg-green-300 border-green-500 text-gray-500"
  def card_scheme(%{type: :change, active: true}), do: "bg-yellow-300 border-yellow-800"
  def card_scheme(%{type: :change, active: false}), do: "bg-yellow-300 border-yellow-500 text-gray-500"

  def render_active_item(%{id: item_id, options: options, active: _active} = assigns) do
    Logger.debug("Item ID: #{item_id} active? #{assigns.active}")
    case Enum.find(options, fn {_option_type, item_list} -> (Enum.member?(item_list, item_id)) end) do
      {action, _} ->  render_actionable_item(assigns, action)
      _ -> render_passive_item(assigns)
    end
  end

  def render_item_body(assigns) do
    ~L"""
      <div class="rounded-full <%= card_scheme(%{type: @type, active: @active}) %> h-6 w-6 flex items-center justify-center text-sm border-2">
        <%= @initials %>
      </div>
      <div class="text-xs align-bottom">
        <%= if @blocked do %>B<% end %>
      </div>
    """
  end

  def render_actionable_item(assigns, action) do
    ~L"""
      <div class="flex justify-between border-2 shadow <%= card_scheme(%{type: @type, active: @active}) %> w-16 h-10 m-1 p-1
                  hover:shadow-outline hover:border-4"
          phx-click="move"
          phx-value-type="<%= action %>"
          phx-value-id="<%= @id %>">
          <%= render_item_body(assigns) %>
      </div>
    """
  end

  def render_passive_item(assigns) do
    ~L"""
      <div class="flex justify-between border-2 <%= card_scheme(%{type: @type, active: @active}) %> w-16 h-10 m-1 p-1">
        <%= render_item_body(assigns) %>
      </div>
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
        <div class="border-2 <%= card_scheme(%{type: item.type, active: false}) %> w-4 px-1 py-3 m-1"></div>
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