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
    <div>
      <%= if @username == nil do %>
        <div class="absolute z-40 h-full w-full flex flex-col items-center justify-center
                    bg-gray-600 bg-opacity-50
                    font-sans">
          <div class="bg-white rounded shadow p-8 m-4 max-w-xs max-h-full text-center overflow-y-scroll">
            <form phx-submit="add_player">
              <p>Please enter an initial with which to identified your items</p>
              <input class="border-2 border-gray-800 rounded-md" name="initials", type="text">
            </form>
          </div>
        </div>
      <% end %>
      <div class="z-20">
        <div class="flex justify-between pt-4">
          <%= turn_display(%{turn: @turn, player: @player}) %>
          <%= if @state == :setup do %>
            <button class="border-2 border-gray-800 rounded-md bg-green-400" phx-click="start">start</button>
          <% else %>
            <%= render_turn_instructions(@player) %>
          <% end %>
          <%= render_score_display(assigns) %>
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
      <p class="class="text-gray-900 text-base text-center border-2 border-gray-500>
        Game name: <%= @game_name %> Player Count: <%= Enum.count(@players) %>
        Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
      </p>
    </div>
    """
  end

  # def turn_display(%{player: nil, turn: turn}), do: render_turn_display(%{font_color: "text-grey-400", nr: turn})
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

  def render_turn_instructions(assigns) do
    ~L"""
    <div class="flex-grow border-2 border-gray-700 rounded-md text-sm text-center">
      <p class="text-base font-bold">Instructions</p>
      <%= if @state == :done do %>
        <p>You are waiting for the other players to go</p>
      <% else %>
        <%= cond do %>
        <% @machine == :black -> %>
          <%=cond do %>
          <% ! Enum.empty?(@options.block) && ! Enum.empty?(@options.start)  -> %>
            <p>You must block one unblocked item</p>
            <p>and you must also start one new item</p>
          <% ! Enum.empty?(@options.block) -> %>
            <p>You must block one unblocked item</p>
          <% ! Enum.empty?(@options.start) -> %>
            <p>You must start one new item</p>
          <% end %>
        <% @machine == :red -> %>
          <p>You can either move one of your unblocked items one column right</p>
          <p>or you can unblock one of your blocked items</p>
          <p>or you can start one new item (if any remain)</p>
        <% true -> %>
          <p>Other</p>
          <p></p>
          <p></p>
        <% end %>
      <% end %>
    </div>
    """
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
      <div class="w-1/6 flex flex-col
                  border-2 border-black rounded-md
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
              <div <%= if @blocked do %> class="font-black" <% end %> >
                <%= @initials %>
              </div>
            </div>
          <% else %>
            <div class="border-2 shadow bg-yellow-300 border-yellow-800 w-8 px-1 py-3 m-1"
                phx-click="move"
                phx-value-type="<%= type %>"
                phx-value-id="<%= @id %>">
              <div <%= if @blocked do %> class="font-black" <% end %> >
                <%= @initials %>
              </div>
            </div>
        <% end %>
        """
      _ ->
        ~L"""
          <%= if @type == :task do %>
            <div class="border-2 bg-green-500 border-green-500 w-8 px-1 py-3 m-1">
              <div <%= if @blocked do %> class="font-black" <% end %> >
                <%= @initials %>
              </div>
            </div>
          <% else %>
            <div class="border-2 bg-yellow-300 border-yellow-300 w-8 px-1 py-3 m-1">
              <div <%= if @blocked do %> class="font-black" <% end %> >
                <%= @initials %>
              </div>
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
          <%= render_active_item(collect_item_data(item, assigns.players, @player)) %>
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

  def fmt(nr, fmt), do: to_string(:io_lib.format(fmt, [nr]))
end
