defmodule GamesRoomWeb.ChangebanLive do
  use GamesRoomWeb, :live_view

  # use Phoenix.LiveView
  alias GamesRoom.Counter
  alias Phoenix.PubSub
  alias GamesRoom.Presence
  alias Changeban.{GameServer, GameSupervisor, Player, Item}

  @topic Counter.topic
  @presence_topic "presence"

  @doc """
    Only called if user is already created

    creates user presence in game
    If there is a game_name
     in the socket - carry on
    If there is no game_name
     create a game
  """
  @impl true
  def mount(params, %{"username" => username}, socket) do
    IO.puts("In GamesRoomWeb.ChangebanLive.mount ---------------------------------------")
    IO.puts("username: #{inspect username}, params: #{inspect params}")
    PubSub.subscribe(GamesRoom.PubSub, @topic)

    Presence.track(self(), @presence_topic, socket.id, %{})
    GamesRoomWeb.Endpoint.subscribe(@presence_topic)

    initial_present = Presence.list(@presence_topic) |> map_size

    IO.puts "Before: Mounted Socket Assigns: #{inspect socket.assigns}"

    game_name =
      if Map.get(socket.assigns, :game_name) do
        socket.assigns.game_name
      else
        if Map.get(params,"id") do
          Map.get(params,"id")
        else
          new_name = gen_game_name()
          GameSupervisor.start_game(new_name)
          new_name
        end
      end

    {:ok, player_id, _} = GameServer.add_player(game_name)
    GameServer.start_game(game_name)

    {items, players, turn, score} = GameServer.view(game_name)
    IO.puts("MOUNTING: id:        #{inspect player_id, pretty: true}")
    IO.puts("MOUNTING: items:     #{inspect items, pretty: true}")
    IO.puts("MOUNTING: turn:      #{inspect turn, pretty: true}")
    IO.puts("MOUNTING: score:     #{inspect score, pretty: true}")

    new_socket = assign(socket,
        val: Counter.current(),
        game_name: game_name,
        player_id: player_id,
        items: items,
        player: Enum.at(players, player_id),
        turn: turn,
        score: score,
        present: initial_present,
        username: username)

        IO.puts "After: player_id:              #{inspect new_socket.assigns.player_id}"
        IO.puts "After: Mounted Socket Assigns: #{inspect new_socket.assigns}"

    {:ok, new_socket }
  end

  @impl true
  def mount(params, _session, socket) do
    IO.puts("Redirecting from GamesRoomWeb.ChangebanLive.mount ---------------------------------------")
    # put_flash(socket, :info, "test_game")
    game_name
     = Map.get(params,"id", "")
    {:ok, push_redirect(socket, to: "/login/#{game_name
    }")}
  end

  @impl true
  def handle_event("inc", _, socket) do
    {:noreply, assign(prep_assigns(socket), :val, Counter.incr())}
  end

  @impl true
  def handle_event("dec", _, socket) do
    {:noreply, assign(prep_assigns(socket), :val, Counter.decr())}
  end

  @impl true
  def handle_event("move", %{"id" => id}, socket) do
    IO.puts("GamesRoomWeb.ChangeBanLive.handle_event - move #{id} ---------------------------------------")
    GameServer.move(socket.assigns.game_name, :move, String.to_integer(id), socket.assigns.player_id)
    {:noreply, assign(prep_assigns(socket), :val, Counter.decr())}
  end

  def handle_event("start", %{"id" => id}, socket) do
    IO.puts("GamesRoomWeb.ChangeBanLive.handle_event - start #{id} ---------------------------------------")
    GameServer.move(socket.assigns.game_name, :start, String.to_integer(id), socket.assigns.player_id)
    {:noreply, assign(prep_assigns(socket), :val, Counter.decr())}
  end

  @impl true
  def handle_info({:count, count}, socket) do
    {:noreply, assign(prep_assigns(socket), val: count)}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{present: present}} = socket
      ) do
    new_present = present + map_size(joins) - map_size(leaves)

    {:noreply, assign(prep_assigns(socket), :present, new_present)}
  end

  defp prep_assigns(socket) do
    {items, players, turn, score} = GameServer.view(socket.assigns.game_name)
    IO.puts("PREP_ASSIGNS #{inspect socket.assigns, pretty: true}")
    assign(socket,
      items: items,
      player: Enum.at(players, socket.assigns.player_id),
      turn: turn,
      score: score)
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="">
      <p class="py-2 text-gray-800 center">
        The count is: <b><%= @val %></b>
        <button class="border-2 border-gray-800 w-5 rounded-md bg-red-400" phx-click="dec">-</button>
        <button class="border-2 border-gray-800 w-5 rounded-md bg-blue-400" phx-click="inc">+</button>
        Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
      </p>

      <p>Turn: <%= @turn %></p>

      <div class="grid grid-cols-cb grid-rows-cb my-4 container border border-gray-800 text-center">
        <%= headers(assigns) %>
        <div class="col-start-1 row-start-3 row-span-5 border border-gray-800">
            <%= au_items(assigns) %>
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

  def collect_item_data(%Item{id: item_id, type: type}, %Player{id: player_id, options: options}) do
    new_assigns = %{id: item_id, type: type, player_id: player_id, items: options}
    IO.puts("au_data: #{inspect new_assigns}")
    new_assigns
  end

  def render_au_item(%{id: item_id, items: items} = assigns) do
    if (Enum.find(items[:start], &(&1 == item_id)) == nil) do
      ~L"""
        <%= if @type == :task do %>
          <div class="border bg-green-500 border-green-500 w-8 px-1 py-3 m-1"></div>
        <% else %>
          <div class="border bg-yellow-300 border-yellow-300 w-8 px-1 py-3 m-1"></div>
        <% end %>
      """
    else
      ~L"""
        <%= if @type == :task do %>
          <div class="border bg-green-500 border-green-700 w-8 px-1 py-3 m-1"
                phx-click="start"
                phx-value-id="<%= @id %>"
        ></div>
        <% else %>
          <div class="border bg-yellow-300 border-yellow-800 w-8 px-1 py-3 m-1"
                phx-click="start"
                phx-value-id="<%= @id %>"
          ></div>
        <% end %>
      """
    end
  end

#   def item_border(type) do
#     if type == :task, do: "border-green-700", else: "border-yellow-300"
#   end
#   def item_bg(type) do
#     if type == :task, do: "bg-green-500", else: "bg-yellow-300"
#   end
#   def act(color, blocked) do
#     cond do
#       color == :black && blocked, do: "phx-click='block'", else: "phx-click='move'"
#     end color == :black, do: "phx-click='block'", else: "phx-click='move'"
#   end

#   def moving_item(assigns) do
#     <div class="border <%= item_bg(@type) %> <%= item_border(@type) %> w-8 px-1 py-3 m-1"
#     <%= item_bg(@type) %>
#     phx-value-id="<%= @id %>">
#   <%= @id %>
# </div>
#   end

  def render_active_item(%{id: item_id, items: items} = assigns) do
    # IO.puts("render_item: #{inspect assigns}")
    if (Enum.find(items[:move], &(&1 == item_id)) == nil) do
      ~L"""
          <%= if @type == :task do %>
            <div class="border bg-green-500 border-green-500 w-8 px-1 py-3 m-1"></div>
          <% else %>
            <div class="border bg-yellow-300 border-yellow-300 w-8 px-1 py-3 m-1"></div>
          <% end %>
        """
    else
      ~L"""
        <%= if @type == :task do %>
          <div class="border bg-green-500 border-green-700 w-8 px-1 py-3 m-1"
              phx-click="move"
              phx-value-id="<%= @id %>">
            <%= @id %>
          </div>
        <% else %>
          <div class="border bg-yellow-300 border-yellow-800 w-8 px-1 py-3 m-1"
              phx-click="move"
              phx-value-id="<%= @id %>">
          <%= @id %>
        </div>
      <% end %>
      """
    end
  end

  def render_finished_item(assigns) do
    # IO.puts("render_item: #{inspect assigns}")
    ~L"""
      <%= if @type == :task do %>
        <div class="border bg-green-500 border-green-700 w-4 px-1 py-3 m-1"></div>
      <% else %>
        <div class="border bg-yellow-300 border-yellow-800 w-4 px-1 py-3 m-1"></div>
      <% end %>
    """
  end

  def au_items(assigns) do
    ~L"""
    <div class="flex flex-wrap">
      <%= for item <- Map.get(assigns.items, 0, []) do %>
        <%= render_au_item(collect_item_data(item, @player)) %>
      <% end %>
    </div>
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
