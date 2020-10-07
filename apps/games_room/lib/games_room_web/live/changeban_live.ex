defmodule GamesRoomWeb.ChangebanLive do
  require Logger
  use GamesRoomWeb, :live_view

  alias Phoenix.{LiveView, PubSub}
  alias GamesRoom.Presence
  alias Changeban.{GameServer, GameSupervisor, Player, Item}

  @doc """
    Sets placeholders for the various keys used by the app in the socket
  """
  @impl true
  def mount(_params, _session, socket) do
    new_socket =
      assign(socket,
        game_name: nil,
        items: nil,
        players: nil,
        turn: nil,
        score: nil,
        state: nil,
        wip_limits: nil,
        present: 0,
        player: nil,
        player_id: nil,
        username: nil,
        leader: false
      )

    {:ok, new_socket}
  end

  @doc """
  Game changes are notified with a simple flag.
  Each Liveview in the game will then check the game state
  """
  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    Logger.debug(
      "Change notify: #{inspect(assigns.game_name)} seen by: #{inspect(assigns.username)}"
    )

    {:noreply, update_only(socket)}
  end

  @impl true
  def handle_info(
        %{topic: topic, event: "presence_diff", payload: %{leaves: leaves}},
        supplied_socket
      ) do
    socket = LiveView.clear_flash(supplied_socket)

    if !Enum.empty?(leaves) do
      %{initials: initials, player_id: id} =
        leaves
        |> Map.values()
        |> List.first()
        |> Map.get(:metas)
        |> List.first()

      GameServer.remove_player(socket.assigns.game_name, id)

      Logger.debug("Player: #{initials} id: #{id} has left game: #{topic}")

      {:noreply,
       socket
       |> assign(present: Presence.list(topic) |> map_size)
       |> LiveView.put_flash(:info, "Player: #{initials} has left game #{topic}")
       |> update_only}
    else
      {:noreply, assign(socket, present: Presence.list(topic) |> map_size)}
    end
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** UNKNOWN-EVENT #{inspect(evt)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "new_game",
        %{"initials" => supplied_initials, "wip" => supplied_wip_type},
        supplied_socket
      ) do
    socket = LiveView.clear_flash(supplied_socket)
    initials = String.upcase(supplied_initials)
    game_name = gen_game_name()
    wip_type = String.to_existing_atom(supplied_wip_type)

    Logger.debug(
      "new_game: #{inspect(game_name)} with WIP limit type #{wip_type} and player: #{initials}"
    )

    PubSub.subscribe(GamesRoom.PubSub, game_name)
    GameSupervisor.create_game(game_name)
    GameServer.set_wip(game_name, wip_type, 2)
    {:ok, player_id, player} = GameServer.add_player(game_name, initials)
    Presence.track(self(), game_name, socket.id, %{player_id: player_id, initials: initials})

    {:noreply,
     update_only(
       assign(socket,
         game_name: game_name,
         player: player,
         player_id: player_id,
         username: initials
       )
     )}
  end

  @impl true
  def handle_event(
        "join_game",
        %{"initials" => supplied_initials, "game_name" => supplied_game_name},
        supplied_socket
      ) do
    socket = LiveView.clear_flash(supplied_socket)
    initials = String.upcase(supplied_initials)
    game_name = String.upcase(supplied_game_name)
    Logger.debug("add_player: #{inspect(initials)} to existing game: #{inspect(game_name)}")

    cond do
      not GameServer.game_exists?(game_name) ->
        Logger.info("Non existant game")
        {:noreply, LiveView.put_flash(socket, :error, "Game #{game_name} does not exist")}

      GameServer.joinable?(game_name) ->
        Logger.debug("Allow player to join game: #{game_name}")
        PubSub.subscribe(GamesRoom.PubSub, game_name)
        {:ok, player_id, player} = GameServer.add_player(game_name, initials)
        Presence.track(self(), game_name, socket.id, %{player_id: player_id, initials: initials})

        {:noreply,
         update_and_notify(
           assign(socket,
             game_name: game_name,
             player: player,
             player_id: player_id,
             username: initials
           )
         )}

      true ->
        Logger.debug("Allow player to view game game: #{game_name}")
        PubSub.subscribe(GamesRoom.PubSub, game_name)
        {:noreply, update_and_notify(assign(socket, game_name: game_name))}
    end
  end

  @impl true
  def handle_event("start", _, supplied_socket) do
    socket = LiveView.clear_flash(supplied_socket)
    GameServer.start_game(socket.assigns.game_name)
    {:noreply, update_and_notify(socket)}
  end

  @impl true
  def handle_event("move", %{"id" => id, "type" => type}, supplied_socket) do
    socket = LiveView.clear_flash(supplied_socket)
    type_atom = String.to_existing_atom(type)
    Logger.debug("MOVE: item: #{id} act: #{type_atom}")

    GameServer.move(
      socket.assigns.game_name,
      type_atom,
      String.to_integer(id),
      socket.assigns.player_id
    )

    {:noreply, update_and_notify(socket)}
  end

  defp prep_assigns(socket, items, players, turn, score, state, wip_limits) do
    player =
      if socket.assigns.player_id do
        Enum.at(players, socket.assigns.player_id)
      else
        nil
      end

    new_socket =
      assign(socket,
        items: items,
        players: players,
        player: player,
        turn: turn,
        score: score,
        state: state,
        wip_limits: wip_limits
      )

    Logger.debug("""
    ASSIGNS:
    game_name: #{inspect(new_socket.assigns.game_name)}
    present: #{inspect(new_socket.assigns.present)}
    name: #{inspect(new_socket.assigns.username)}
    turn: #{inspect(new_socket.assigns.turn)}
    game_state: #{inspect(new_socket.assigns.state)}
    wip_limits: #{inspect(new_socket.assigns.wip_limits)}
    """)

    if not is_nil(new_socket.assigns.player) do
      Logger.debug("""
      PLAYER_ASSIGNS
      turn_type: #{inspect(new_socket.assigns.player.machine)}
      state: #{inspect(new_socket.assigns.player.state)}
      past: #{inspect(new_socket.assigns.player.past)}
      options: #{inspect(new_socket.assigns.player.options)}
      """)
    end

    new_socket
  end

  defp update_and_notify(socket) do
    Logger.debug("UPDATE-AND-NOTIFY - #{socket.assigns.game_name} - #{socket.assigns.username}")
    {items, players, turn, score, state, wip_limits} = GameServer.view(socket.assigns.game_name)
    PubSub.broadcast(GamesRoom.PubSub, socket.assigns.game_name, :change)
    prep_assigns(socket, items, players, turn, score, state, wip_limits)
  end

  defp update_only(socket) do
    Logger.debug("UPDATE-ONLY - #{socket.assigns.game_name} - #{socket.assigns.username}")
    {items, players, turn, score, state, wip_limits} = GameServer.view(socket.assigns.game_name)
    prep_assigns(socket, items, players, turn, score, state, wip_limits)
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="relative">
      <%= cond do %>
        <% is_nil(@username) -> %>
          <%= cond do %>
            <% is_nil(@game_name) -> %>
              <%= render_join_view(assigns) %>
            <% GameServer.joinable?(@game_name) -> %>
              <%= render_join_view(assigns) %>
            <% true -> %>
              <%= render_game_full(assigns) %>
              <%= render_game(assigns) %>
          <% end %>
        <% ! is_nil(@game_name) -> %>
          <%= render_game(assigns) %>
      <% end %>
    </div>
    """
  end

  def render_game_full(assigns) do
    ~L"""
        <div class="absolute z-40 flex flex-col items-center justify-center
                    w-full h-screen
                    font-sans">
          <div class="bg-white opacity-50 rounded shadow p-8 m-4 max-w-s max-h-full text-center overflow-y-scroll">
            <p class="text-center">Game <%= @game_name %> can no longer be joined.</p>
            <p class="text-center">You can watch the game in progress here.</p>
          </div>
        </div>
    """
  end

  def render_join_view(assigns) do
    ~L"""
      <div class="flex h-screen">
        <div class="w-2/3 flex flex-1 overflow-y-scroll">
          <div>
            <h1 class="py-4 text-xl font-black">Instructions</h1>
            <p class="pb-2">Changeban is a Lean Startup-flavoured Kanban simulation game.</p>
            <p class="pb-2">It was created by Mike Burrows, the founder of
              <a class="text-blue-500" href="https://www.agendashift.com" target="_blank">Agendashift</a>,
              as an in-person workshop game.  To understand the objectives and outcomes of playing the
              game have a look at the
              <a class="text-blue-500" href="https://www.agendashift.com/resources/changeban" target="_blank">Changeban</a>
              page, on the Agendashift site.</p>

            <p class="pb-2">In this online version you will see what type of turn you have and what you can do.  The game will
              not allow you to make an invalid move.  Simply look at the bold tickets and pick one.  Clicking
              on it will make the move.</p>
            <p class="pb-2">When played in person randomness is introduced for play by each player drawing a card,
              which could be red or black. Here the game will deal your colour for you.</p>
            <h2 class="py-2 text-lg">For a RED Card</h2>
              <li>EITHER advance one of your unblocked items one column rightwards</li>
              <li>OR unblock one of your blocked items by crossing out its ‘B’ mark</li>
              <li>OR start a new item if any remain - move it to the first in-progress column</li>
              <li>If and only if you can’t make one of these moves for yourself, help someone! Advance
                  or unblock another player’s item Whenever you accept an item, reject another, chosen
                  by the whole team</li>
            <h2 class="py-2 text-lg">For a BLACK Card</h2>
            <p>After your daily standup meeting:</p>
            <li>BOTH block one of your currently unblocked items if you have any</li>
            <li>AND start a new item if any remain – even if you had nothing to block</li>
            <li>If and only if you can’t <i>start a new item</i>, help someone! Advance or unblock another
                player’s item.</li>
            <h2 class="py-2 text-lg">Rejecting Items</h2>
            <p>Whether you are playing a red or black turn whenever you accept an item, reject another,
              chosen by the whole team</p>
            <h2 class="py-2 text-lg">Scoring</h2>
            <p>Changeban simulates the idea that many of our ideas will be rejected as we find out about them.
               There are two colours of items representing different kinds of work.  To maimise the team's score
               There should be a balance of completeion and rejection and a balance of types of work.</p>
            <p>1 point for each Accepted item, up to a maximum of 4 per colour – 8 points available</p>
            <p>1 point for each colour represented in each subcolumn of Rejected – 8 points available</p>
            <p>A bonus point for each subcolumn of Rejected that contains exactly 2 items, 1 of each colour –
               4 points available</p>
            <p>The maximum score is 20</p>
            <h2 class="py-2 text-lg">Playing Multiple Games</h2>
            <p>You cannot restart a game but you can play as many times as you like, simply start a new game.</p>
            <h2 class="py-2 text-lg">Limiting WIP</h2>
            <p>The game can be played without WIP limits, with a limit for each column or a consolidated
              limit across all the in-progress columns.  Simple check the appropriate box when creating a game.</p>
            <p>After you have started a game the six character game name is displayed in the bottom left
              corner.  Pass this on to the players for them to join.</p>
            <p>Each game can hold a maximum of 5 players and you cannot join after it has begun.
               If you try to join a full, or running game you will be given the opportunity to watch it play."</p>
          </div>
        </div>
        <div class="w-1/3 rounded shadow b-1 p-4 m-4">
          <p class="text-left  font-bold">Do you want to join one a game?</p>
          <p class="text-left pb-4">Enter your 6 character game name, your one or two character initials and click "Join Game"</p>
          <form phx-submit="join_game">
            <div class="grid grid-cols-3 grid-rows-2 gap-2 font-bold">
              <label class="col-start-1 row-start-1 text-gray-700 text-sm font-bold" for="game_name">Game Name:</label>
              <input class="col-start-1 row-start-row-2 shadow appearance-none border rounded text-gray-700 uppercase
                            placeholder-gray-300 focus:outline-none focus:shadow-outline"
                      placeholder="XXXXXX" name="game_name" id="game_name" type="text" maxlength="6"
                      <%= if ! is_nil(@game_name) do %> value="<%= @game_name %>" <% end %> >
              <label class="col-start-2 row-start-1 text-gray-700 text-sm font-bold" for="initials placeholder="XX">Initials:</label>
              <input class="col-start-2 row-start-2 shadow appearance-none border rounded focus:outline-none focus:shadow-outline placeholder-gray-300"
                      name="initials" id="initials" type="text" maxlength="2" placeholder="XX">
              <button type="submit" class="col-start-3 row-start-2  bg-green-300 hover:bg-green-700 text-white font-bold
                                            rounded focus:outline-none focus:shadow-outline" >
                Join Game
              </button>
            </div>
          </form>
          <p class="text-left pt-2 font-bold">Or start a new one?</p>
          <p class="text-left pb-4">Enter your one or two character initials, select your Work in Progress (WIP) limit type and click "New Game"</p>
          <form phx-submit="new_game">
            <div class="grid grid-cols-3 grid-rows-3 gap-2">
              <label class="col-start-2 row-start-1 text-gray-700 text-sm font-bold" for="initials">Initials:</label>
              <input class="col-start-2 row-start-2 shadow appearance-none border rounded focus:outline-nonefocus:shadow-outline placeholder-gray-300"
                    name="initials" id="initials" type="text" maxlength="2" placeholder="XX">
              <button type="submit" class="col-start-3 row-start-2 bg-green-300 hover:bg-green-700 text-white font-bold
                                            rounded focus:outline-none focus:shadow-outline" >
                New Game
              </button>
              <div class="col-start-1 row-start-3">
                <input type="radio" id="none" name="wip" value="none" checked>
                <label for="none">None</label>
              </div>
                <div class="col-start-2 row-start-3">
                <input type="radio" id="std" name="wip" value="std">
                <label for="std">WIP</label>
              </div>
              <div class="col-start-3 row-start-3">
                <input type="radio" id="con" name="wip" value="con">
                <label for="con">ConWIP</label>
              </div>
            </div>
          </form>
        </div>
      </div>
    """
  end

  def render_game(assigns) do
    ~L"""
      <div class="z-20">
        <div class="flex justify-between pt-4 h-32">
          <%= turn_display(%{turn: @turn, player: @player}) %>
          <%= render_state_instructions(assigns) %>
          <%= render_score_display(assigns) %>
        </div>
        <%= render_game_grid(assigns) %>
      </div>
      <p class="class="text-gray-900 text-base text-center border-2 border-gray-500>
        Game name: <%= @game_name %> Player Count: <%= Enum.count(@players) %>
        Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
      </p>
    """
  end

  def render_game_grid(assigns) do
    ~L"""
    <div class="grid grid-cols-cb grid-rows-cb my-3 container border border-gray-800 text-center">
      <%= headers(assigns) %>
      <div class="col-start-1 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style="background-image: url('/images/au_text.svg'); background-repeat: no-repeat">
        <%= active_items(assigns, 0) %>
      </div>
      <div class="col-start-2 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style="background-image: url('/images/nc_text.svg'); background-repeat: no-repeat">
        <%= active_items(assigns, 1) %>
      </div>
      <div class="col-start-3 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style="background-image: url('/images/va_text.svg'); background-repeat: no-repeat">
        <%= active_items(assigns, 2) %>
      </div>
      <div class="col-start-4 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style="background-image: url('/images/vp_text.svg'); background-repeat: no-repeat">
        <%= active_items(assigns, 3) %>
      </div>

      <div class="col-start-5 row-start-4 col-span-4 border border-gray-800 bg-contain"
           style="background-image: url('/images/dn_text.svg'); background-repeat: no-repeat; background-position: center;">
        <%= completed_items(assigns, 4) %>
      </div>

      <div class="col-start-5 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style="background-image: url('/images/rj_text.svg'); background-repeat: no-repeat">
        <%= completed_items(assigns, 5) %>
      </div>
      <div class="col-start-6 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style="background-image: url('/images/rj_text.svg'); background-repeat: no-repeat">
        <%= completed_items(assigns, 6) %>
      </div>
      <div class="col-start-7 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style="background-image: url('/images/rj_text.svg'); background-repeat: no-repeat">
        <%= completed_items(assigns, 7) %>
      </div>
      <div class="col-start-8 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style="background-image: url('/images/rj_text.svg'); background-repeat: no-repeat">
        <%= completed_items(assigns, 8) %>
      </div>
    </div>
    """
  end

  def render_state_instructions(assigns) do
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

  def render_turn_instructions(assigns) do
    ~L"""
    <div class="flex-grow border-2 border-gray-700 mx-4 rounded-md text-sm text-center">
      <p class="text-base font-bold">Instructions</p>
      <%= render_specific_instructions(assigns.player) %>
    </div>
    """
  end

  def render_specific_instructions(%Player{} = player) do
    cond do
      player.state == :done ->
        render_done_instructions(player)

      helping?(player.options) ->
        render_help_instructions(player)

      rejecting?(player.options) ->
        render_reject_instructions(player)

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

  def render_done_instructions(assigns) do
    ~L"""
    <p class="text-gray-600">You are waiting for the other players to go</p>
    """
  end

  def render_help_instructions(assigns) do
    ~L"""
    <p>You cannot move your own items so you can help someone!</p>
    <p class="font-black" >Unblock or move someone else's item</p>
    """
  end

  def render_reject_instructions(assigns) do
    ~L"""
    <p>You have accepted an item</p>
    <p>Now you can reject any item on the board</p>
    <p class="font-black" >Discuss with the other players and reject an item</p>
    """
  end

  def can_class(action_list) do
    if ! Enum.empty?(action_list) do
      "font-black"
    else
      "text-grey-700"
    end
  end

  def render_black_instructions(assigns) do
    ~L"""
      <p>You must both:</p>
      <p class="<%= can_class(@options.block) %>">block one unblocked item</p>
      <p class="<%= can_class(@options.start) %>">and start one new item</p>
    """
  end

  def render_red_instructions(assigns) do
    ~L"""
      <p>You must either:</p>
      <p class="<%= can_class(@options.move) %>">move one of your unblocked items one column right</p>
      <p class="<%= can_class(@options.unblock) %>">or unblock one of your blocked items</p>
      <p class="<%= can_class(@options.start) %>">or start one new item</p>
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
      player == nil || turn == 0 || player.state == :done ->
        render_non_turn_display(%{colour: "gray-400", nr: turn})

      player.machine == :red ->
        render_red_turn_display(%{colour: "red-700", nr: turn})

      true ->
        render_black_turn_display(%{colour: "black", nr: turn})
    end
  end

  def render_non_turn_display(assigns) do
    ~L"""
      <div class="w-1/6 flex
                  border-2 border-gray-400 rounded-md">
        <div class="w-1/4 flex flex-col">
        </div>
        <div class="w-2/4 flex flex-col justify-center">
          <div class="text-center text-gray-400 text-2xl">Turn:</div>
          <div class="text-center text-gray-400 text-2xl"><%= to_string(@nr) %></div>
        </div>
        <div class="w-1/4 flex flex-col flex-col-reverse">
        </div>
      </div>
    """
  end

  def render_black_turn_display(assigns) do
    ~L"""
      <div class="w-1/6 flex-grow-0 flex
                  border-2 border-black rounded-md">
        <div class="w-1/4 flex flex-col flex-col-reverse">
          <img class="p-1 object-contain" src="/images/black_spade.svg" alt="black spade">
        </div>
        <div class="w-2/4 flex flex-col justify-center">
          <div class="text-center text-black text-2xl">Turn:</div>
          <div class="text-center text-black text-2xl"><%= to_string(@nr) %></div>
        </div>
        <div class="w-1/4 flex flex-col">
          <img class="p-1 object-contain" src="/images/black_club.svg" alt="black club">
        </div>
      </div>
    """
  end

  def render_red_turn_display(assigns) do
    ~L"""
      <div class="w-1/6 flex-grow-0 flex
                  border-2 border-red-700 rounded-md">
        <div class="w-1/4 flex flex-col">
          <img class="p-1 object-contain" src="/images/red_diamond.svg" alt="red diamond">
        </div>
        <div class="w-2/4 w-2/4 flex flex-col justify-center">
          <div class="text-center text-red-700 text-2xl">Turn:</div>
          <div class="text-center text-red-700 text-2xl"><%= to_string(@nr) %></div>
        </div>
        <div class="w-1/4 flex flex-col flex-col-reverse">
          <img class="p-1 object-contain" src="/images/red_heart.svg" alt="red heart">
        </div>
      </div>
    """
  end

  def render_score_display(assigns) do
    ~L"""
      <div class="w-1/6 flex flex-col border-2 border-black rounded-md
                  text-black text-2xl">
        <div class="text-center">Score:</div>
        <div class="text-center"><%= to_string(@score) %></div>
      </div>
    """
  end

  def collect_item_data(
        %Item{id: item_id, type: type, blocked: blocked, owner: owner_id},
        players,
        nil
      ) do
    %{
      id: item_id,
      type: type,
      blocked: blocked,
      initials: get_initials(owner_id, players),
      options: [],
      action: nil
    }
  end

  def collect_item_data(
        %Item{id: item_id, type: type, blocked: blocked, owner: owner_id},
        players,
        %Player{options: options}
      ) do
    %{
      id: item_id,
      type: type,
      blocked: blocked,
      initials: get_initials(owner_id, players),
      options: options,
      action: find_action(options, item_id)
    }
  end

  def find_action(options, item_id) do
    {action, _} =
      Enum.find(options, {nil, []}, fn {_option_type, item_list} ->
        Enum.member?(item_list, item_id)
      end)

    action
  end

  def get_initials(nil, _players), do: ""
  def get_initials(owner_id, players), do: Enum.at(players, owner_id).initials

  def card_scheme(%{type: :task, action: nil}), do: "bg-green-300 border-green-500 text-gray-500"
  def card_scheme(%{type: :task, action: _}), do: "bg-green-500 border-green-800"

  def card_scheme(%{type: :change, action: nil}),
    do: "bg-yellow-300 border-yellow-500 text-gray-500"

  def card_scheme(%{type: :change, action: _}), do: "bg-yellow-300 border-yellow-800"

  def render_item_body(assigns) do
    ~L"""
      <div class="text-sm flex flex-col ml-1 font-bold">
        <%= @initials %>
      </div>
      <div class="text-xs flex flex-col flex-col-reverse mr-1">
        <%= if @blocked do %>B<% end %>
      </div>
    """
  end

  def render_active_item(%{action: action} = assigns) when is_nil(action) do
    ~L"""
      <div class="flex justify-between border-2 <%= card_scheme(%{type: @type, action: @action}) %> w-16 h-10 m-1">
        <%= render_item_body(assigns) %>
      </div>
    """
  end

  def render_active_item(%{action: action} = assigns) do
    ~L"""
      <div class="flex justify-between border-2 <%= card_scheme(%{type: @type, action: @action}) %> w-16 h-10 m-1
                  hover:shadow-outline"
          phx-click="move"
          phx-value-type="<%= action %>"
          phx-value-id="<%= @id %>">
          <%= render_item_body(assigns) %>
      </div>
    """
  end

  @doc """
  Finds the items for the given state id then iterates over them and passes each to
  render_active_item/1
  """
  def active_items(assigns, state_id) do
    ~L"""
      <div class="flex flex-wrap">
        <%= if @state == :running do %>
          <%= for item <- Map.get(assigns.items, state_id, []) do %>
            <%= collect_item_data(item, assigns.players, @player) |> render_active_item() %>
          <% end %>
        <% end %>
      </div>
    """
  end

  def completed_items(assigns, state_id) do
    ~L"""
    <div class="flex flex-wrap">
      <%= for item <- Map.get(assigns.items, state_id, []) do %>
        <div class="border-2 <%= card_scheme(%{type: item.type, action: nil}) %> w-5 h-8 mt-1 ml-1"></div>
      <% end %>
    </div>
    """
  end

  def calculate_wip_for_state(items, state_ids) do
    Enum.map(state_ids, fn id -> Map.get(items, id, []) |> Enum.count() end)
    |> Enum.sum()
  end

  def is_wip_type?({limit_type, _}, type), do: limit_type == type

  def wip_limit({_, value}), do: value

  def headers(assigns) do
    ~L"""
    <div class="col-start-1 row-start-1 row-span-2 border border-gray-800">Agree Urgency</div>
    <div class="col-start-2 col-span-3 row-start-1 border border-gray-800 py-0">
      <p>In progress</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">WIP: <%= calculate_wip_for_state(@items, [1,2,3]) %></div>
        <%= if is_wip_type?(@wip_limits, :con) do %>
          <div class="col-start-2 row-start-1">Limit: <%= wip_limit(@wip_limits) %></div>
        <% end %>
      </div>
     </div>
    <div class="col-start-5 col-span-4 row-start-1 row-span-2 border border-gray-800">Complete</div>

    <div class="col-start-2 row-start-2 border border-gray-800">
      <p>Negotiate Change</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">WIP: <%= calculate_wip_for_state(@items, [1]) %></div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">Limit: <%= wip_limit(@wip_limits) %></div>
        <% end %>
      </div>
    </div>
    <div class="col-start-3 row-start-2 border border-gray-800">
      <p>Validate Adoption</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">WIP: <%= calculate_wip_for_state(@items,[2]) %></div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">Limit: <%= wip_limit(@wip_limits) %></div>
        <% end %>
      </div>
    </div>
    <div class="col-start-4 row-start-2 border border-gray-800">
      <p>Verify Performance</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">WIP: <%= calculate_wip_for_state(@items, [3]) %></div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">Limit: <%= wip_limit(@wip_limits) %></div>
        <% end %>
      </div>
    </div>

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
