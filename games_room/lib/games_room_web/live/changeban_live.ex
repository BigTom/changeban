defmodule GamesRoomWeb.ChangebanLive do
  use GamesRoomWeb, :live_view

  # use Phoenix.LiveView
  alias Phoenix.PubSub
  alias GamesRoom.Presence
  alias Changeban.{GameServer, GameSupervisor, Player, Item}

  @game_topic "game"

  @doc """
    Only called if user is already created

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
    IO.puts("In GamesRoomWeb.ChangebanLive.mount ---------------------------------------")
    IO.puts("game_name: #{inspect game_name}")

    PubSub.subscribe(GamesRoom.PubSub, @game_topic)
    Presence.track(self(), game_name, socket.id, %{player_id: nil})
    GamesRoomWeb.Endpoint.subscribe(game_name)

    initial_present = Presence.list(game_name) |> map_size

    IO.puts "Before: Mounted Socket Assigns: #{inspect socket.assigns}"

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

    IO.puts("INITIAL #{turn} No player yet")

    {:ok, new_socket }
  end

  @impl true
  def mount(params, session, socket) do
    IO.puts("params: #{inspect params}  ---------- NO GAME_NAME_SUPPLIED")
    game_name = gen_game_name()
    GameSupervisor.create_game(game_name)
    mount(%{"game_name" => game_name}, session, socket)
  end

  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    IO.puts("PupSub notify: #{assigns.game_name}")
    {:noreply, update_only(socket)}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}} = evt,
        %{assigns: %{present: present}} = socket
      ) do
    IO.puts("Presence update: #{inspect evt}")
    new_present = present + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :present, new_present)}
  end

  @impl true
  def handle_info(evt, socket) do
    IO.puts("**** UNKNOWN-EVENT ****")
    IO.puts("Info -----: #{inspect evt} :---")
    IO.puts("Socket ---: #{inspect socket} :---")
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_player", %{"initials" => initials}, %{assigns: assigns} = socket) do
    {:ok, id, player} = GameServer.add_player(socket.assigns.game_name, initials)
    IO.puts("Updating presence metadata: #{inspect %{player_id: id}}")
    Presence.update(self(), assigns.game_name, socket.id, %{player_id: id})
    {:noreply, update_and_notify(assign(socket, player: player, player_id: id, username: initials))}
  end

  @impl true
  def handle_event("start", _, socket) do
    GameServer.start_game(socket.assigns.game_name)
    {:noreply, update_and_notify(socket)}
  end

  @impl true
  def handle_event("move", %{"id" => id, "type" => type}, socket) do
    type_atom = String.to_atom(type)
    IO.puts("MOVE: item: #{id} act: #{type_atom}")
    GameServer.move(socket.assigns.game_name, type_atom, String.to_integer(id), socket.assigns.player_id)
    {:noreply, update_and_notify(socket)}
  end

  defp prep_assigns(socket, items, players, turn, score, state) do
    player = if socket.assigns.player_id do
      player = Enum.at(players,socket.assigns.player_id)
      IO.puts("ASSIGNS name: #{socket.assigns.username} turn: #{turn} turn_type: #{player.machine} state: #{player.state} past: #{inspect player.past} options: #{inspect player.options} ")
      player
    else
      IO.puts("ASSIGNS name: #{socket.assigns.username} turn: #{turn} NO PLAYER YET")
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
    <div class="">
      <p class="py-2 text-gray-800 center">
        Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
      </p>

      <%= if @username == nil do %>
        <form phx-submit="add_player">
          <input name="initials", type="text">
        </form>
      <% end %>

      <div>
        Game name: <%= @game_name %> Player Count: <%= Enum.count(@players) %>
        Turn: <%= @turn %> Turn color: <%= if @player != nil, do: @player.machine, else: "----" %> Score: <%= @score %>
        Game is: <%= @state %>
        <%= if @state == :setup do %>
          <button class="border-2 border-gray-800 rounded-md bg-green-400" phx-click="start">start</button>
        <% end %>
      </div>

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
    </div>
    """
  end

  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked}, nil) do
    %{id: item_id, type: type, blocked: blocked, player_id: nil, options: []}
  end

  def collect_item_data(%Item{id: item_id, type: type, blocked: blocked}, %Player{id: player_id, options: options}) do
    new_assigns = %{id: item_id, type: type, blocked: blocked, player_id: player_id, options: options}
    # IO.puts("au_data: #{inspect new_assigns}")
    new_assigns
  end

  def render_active_item(%{id: item_id, options: options} = assigns) do
    case Enum.find(options, fn ({_, v}) -> (Enum.find(v, &(&1 == item_id)) != nil) end) do
      {type, _} ->
        ~L"""
          <%= if @type == :task do %>
            <div class="border-2 shadow bg-green-500 border-green-800 w-8 px-1 py-3 m-1"
                phx-click="move"
                phx-value-type="<%= type %>"
                phx-value-id="<%= @id %>">
                <div <%= if @blocked do %> class="font-black" <% end %> ><%= @id %></div>
            </div>
          <% else %>
            <div class="border-2 shadow bg-yellow-300 border-yellow-800 w-8 px-1 py-3 m-1"
                phx-click="move"
                phx-value-type="<%= type %>"
                phx-value-id="<%= @id %>">
                <div <%= if @blocked do %> class="font-black" <% end %> ><%= @id %></div>
            </div>
        <% end %>
        """
      _ ->
        ~L"""
          <%= if @type == :task do %>
            <div class="border-2 bg-green-500 border-green-500 w-8 px-1 py-3 m-1">
              <div <%= if @blocked do %> class="font-black" <% end %> ><%= @id %></div>
            </div>
          <% else %>
            <div class="border-2 bg-yellow-300 border-yellow-300 w-8 px-1 py-3 m-1">
              <div <%= if @blocked do %> class="font-black" <% end %> ><%= @id %></div>
            </div>
          <% end %>
        """
      end
  end

  def render_finished_item(assigns) do
    # IO.puts("render_item: #{inspect assigns}")
    ~L"""
      <%= if @type == :task do %>
        <div class="border-2 bg-green-500 border-green-800 w-4 px-1 py-3 m-1"></div>
      <% else %>
        <div class="border-2 bg-yellow-300 border-yellow-800 w-4 px-1 py-3 m-1"></div>
      <% end %>
    """
  end

  def active_items(assigns, state) do
    ~L"""
    <div class="flex flex-wrap">
      <%= for item <- Map.get(assigns.items, state, []) do %>
        <%= render_active_item(collect_item_data(item, @player)) %>
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
    List.to_string(for _n <- 0..5, do: String.at("ABCDEFGHIJKLMNPQRSTUVWXYZ123456789", Enum.random(0..33)))
  end
end
