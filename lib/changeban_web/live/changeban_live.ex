defmodule ChangebanWeb.ChangebanLive do
  @moduledoc """
  Liveview to play specific game
  """
  require Logger
  use ChangebanWeb, :live_view

  alias Phoenix.{LiveView, PubSub}
  alias Changeban.Presence
  alias Changeban.{GameServer, Player, Item}

  @doc """
    Sets placeholders for the various keys used by the app in the socket
  """
  @impl true
  def mount(
        %{
          "game_name" => game_name,
          "player_id" => player_id_str,
          "player_initials" => player_initials
        },
        _session,
        socket
      ) do
    Logger.debug("Mount #{game_name} #{player_id_str} #{player_initials}")

    if GameServer.game_exists?(game_name) do
      player_id = String.to_integer(player_id_str)

      already_present =
        not is_nil(
          Map.values(Presence.list(game_name))
          |> Enum.map(&(Map.get(&1, :metas) |> List.first()))
          |> Enum.find(fn %{initials: p, player_id: i} ->
            p == player_initials && i == player_id
          end)
        )

      player = GameServer.get_player(game_name, player_id)

      cond do
        already_present ->
          redirect_to_join(
            socket,
            "Game #{game_name} - player id #{player_id} is already in game"
          )

        player == nil ->
          redirect_to_join(
            socket,
            "Game #{game_name} - player id #{player_id} is already in game"
          )

        player.initials != player_initials ->
          redirect_to_join(
            socket,
            "Game #{game_name} - Supplied initials #{player_initials} do not match those in game #{player.initials}"
          )

        true ->
          {items, players, day, score, state, wip_limits} = GameServer.view(game_name)

          PubSub.subscribe(Changeban.PubSub, game_name)

          Presence.track(self(), game_name, "player:#{player_id}:#{player_initials}", %{
            player_id: player_id,
            initials: player_initials
          })

          new_socket =
            assign(socket,
              game_name: game_name,
              items: items,
              players: players,
              day: day,
              score: score,
              state: state,
              wip_limits: wip_limits,
              present: Presence.list(game_name) |> map_size,
              player: player,
              player_id: player_id,
              username: player_initials
            )

          {:ok, new_socket}
      end
    else
      msg = "Game #{game_name} does not exist, it may have timed out after a period of inactivity"
      Logger.info(msg)
      redirect_to_join(socket, msg)
    end
  end

  @impl true
  def mount(
        %{"game_name" => game_name},
        _session,
        socket
      ) do
    Logger.debug("Mount #{game_name}")

    if GameServer.game_exists?(game_name) do
      {items, players, day, score, state, wip_limits} = GameServer.view(game_name)

      PubSub.subscribe(Changeban.PubSub, game_name)

      {:ok,
       assign(socket,
         game_name: game_name,
         items: items,
         players: players,
         day: day,
         score: score,
         state: state,
         wip_limits: wip_limits,
         present: Presence.list(game_name) |> map_size,
         player: nil,
         player_id: nil,
         username: nil
       )}
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

  @doc """
  Game changes are notified with a simple flag.
  Each Liveview in the game will then check the game state
  """
  @impl true
  def handle_info(:change, %{assigns: assigns} = socket) do
    Logger.debug("CHANGE TO: #{inspect(assigns.game_name)} seen by: #{inspect(assigns.username)}")

    {:noreply, update_only(socket)}
  end

  @impl true
  def handle_info(
        %{topic: topic, event: "presence_diff", payload: %{leaves: leaves}},
        supplied_socket
      ) do
    socket = LiveView.clear_flash(supplied_socket)

    if Enum.empty?(leaves) do
      Logger.debug("PRESENCE CHANGE - new player")

      {:noreply,
       socket
       |> update_only}
    else
      %{initials: initials, player_id: id} =
        leaves
        |> Map.values()
        |> List.first()
        |> Map.get(:metas)
        |> List.first()

      GameServer.remove_player(socket.assigns.game_name, id)

      Logger.debug("PRESENCE: Player: #{initials} id: #{id} has left game: #{topic}")

      {:noreply,
       socket
       |> LiveView.put_flash(:info, "Player: #{initials} has left game #{topic}")
       |> update_only}
    end
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** CHANGEBAN_LIVE UNKNOWN-EVENT #{inspect(evt)}")
    {:noreply, socket}
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
    Logger.debug("MOVE: player: #{socket.assigns.player.initials} item: #{id} act: #{type_atom}")

    GameServer.move(
      socket.assigns.game_name,
      type_atom,
      String.to_integer(id),
      socket.assigns.player_id
    )

    {:noreply, update_and_notify(socket)}
  end

  defp prep_assigns(socket) do
    {items, players, day, score, state, wip_limits} = GameServer.view(socket.assigns.game_name)

    player =
      if socket.assigns.player_id do
        Enum.find(players, &(&1.id == socket.assigns.player_id))
      else
        nil
      end

    new_socket =
      assign(socket,
        items: items,
        players: players,
        player: player,
        day: day,
        score: score,
        state: state,
        wip_limits: wip_limits,
        present: Presence.list(socket.assigns.game_name) |> map_size
      )

    # Logger.debug("ASSIGNS: name: #{inspect(new_socket.assigns.username)} game_name: #{inspect(new_socket.assigns.game_name)} present: #{inspect(new_socket.assigns.present)} day: #{inspect(new_socket.assigns.day)} game_state: #{inspect(new_socket.assigns.state)} wip_limits: #{inspect(new_socket.assigns.wip_limits)}")

    # if not is_nil(new_socket.assigns.player) do
    #   Logger.debug("PLAYER_ASSIGNS name: #{inspect(new_socket.assigns.username)} turn_type: #{inspect(new_socket.assigns.player.machine)} state: #{inspect(new_socket.assigns.player.state)} past: #{inspect(new_socket.assigns.player.past)} options: #{inspect(new_socket.assigns.player.options)}")
    # end

    new_socket
  end

  defp update_and_notify(socket) do
    Logger.debug("NOTIFY game: #{socket.assigns.game_name} from: #{socket.assigns.username}")
    PubSub.broadcast(Changeban.PubSub, socket.assigns.game_name, :change)
    prep_assigns(socket)
  end

  defp update_only(socket) do
    prep_assigns(socket)
  end

  def half_players(players, x), do: Enum.filter(players, fn p -> rem(p.id, 2) == x end)

  def image(file_name), do: Routes.static_path(ChangebanWeb.Endpoint, "/images/#{file_name}")

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
    <div class="z-20">
    <div class="flex justify-between pt-4 h-32">
      <%= render_turn_display(%{day: @day, player: @player}) %>
      <%= render_other_player_state(%{assigns | players: half_players(@players, 0)}) %>
      <%= render_state_instructions(assigns) %>
      <%= render_other_player_state(%{assigns | players: half_players(@players, 1)}) %>
      <%= render_score_display(assigns) %>
    </div>
    <%= render_game_grid(assigns) %>
    </div>
    <p class="text-gray-900 text-base text-center border-2 border-gray-500">
      Game name: <%= @game_name %> Player Count: <%= Enum.count(@players) %>
      Current users: <b><%= @present %></b> You are logged in as: <b><%= @username %></b>
    </p>
    </div>
    """
  end

  def render_game_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-cb grid-rows-cb my-3 container border border-gray-800 text-center">
      <%= headers(assigns) %>
      <div class="col-start-1 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("au_text.svg")}'); background-repeat: no-repeat"}>
        <%= active_items(assigns, 0) %>
      </div>
      <div class="col-start-2 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("nc_text.svg")}'); background-repeat: no-repeat"}>
        <%= active_items(assigns, 1) %>
      </div>
      <div class="col-start-3 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("va_text.svg")}'); background-repeat: no-repeat"}>
        <%= active_items(assigns, 2) %>
      </div>
      <div class="col-start-4 row-start-3 row-span-5 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("vp_text.svg")}'); background-repeat: no-repeat"}>
        <%= active_items(assigns, 3) %>
      </div>

      <div class="col-start-5 row-start-4 col-span-4 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("dn_text.svg")}'); background-repeat: no-repeat; background-position: center;"}>
        <%= completed_items(assigns, 4) %>
      </div>

      <div class="col-start-5 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("rj_text.svg")}'); background-repeat: no-repeat"}>
        <%= completed_items(assigns, 5) %>
      </div>
      <div class="col-start-6 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("rj_text.svg")}'); background-repeat: no-repeat"}>
        <%= completed_items(assigns, 6) %>
      </div>
      <div class="col-start-7 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("rj_text.svg")}'); background-repeat: no-repeat"}>
        <%= completed_items(assigns, 7) %>
      </div>
      <div class="col-start-8 row-start-7 row-span-2 border border-gray-800 bg-contain"
           style={"background-image: url('#{image("rj_text.svg")}'); background-repeat: no-repeat"}>
        <%= completed_items(assigns, 8) %>
      </div>
    </div>
    """
  end

  def render_state_instructions(assigns) do
    case assigns.state do
      :setup -> render_joining_instructions(assigns)
      :day -> render_turn_instructions(assigns)
      :night -> render_turn_instructions(assigns)
      :done -> render_simulation_over(assigns)
    end
  end

  def render_joining_instructions(assigns) do
    ~H"""
      <div class="w-1/2 flex-grow flex flex-col border-2 rounded-md
                  border-green-600 text-green-600
                  items-center text-center">
        <p>When all players have joined press "START SIMULATION"</p>
        <button class="border-2 rounded-md border-gray-800 bg-green-400 w-1/2"
                phx-click="start">START SIMULATION</button>
      </div>
    """
  end

  def render_observer_instructions(assigns) do
    ~H"""
    <div class="flex-grow flex flex-col items-center">
      <p class="text-gray-600">You are observing game <%= @game_name %></p>
      <p class="text-gray-600">You can watch the game in progress here.</p>
      <a href={"/stats/#{@game_name}"}
          target="_blank"
          class="mt-2 border-2 rounded-md w-1/2
                 border-gray-800 bg-gray-400
                 hover:shadow-outline hover:bg-gray-600">
        View Statistics
      </a>
    </div>
    """
  end

  def render_simulation_over(assigns) do
    ~H"""
      <div class="w-1/2 flex-grow flex flex-col border-2 rounded-md
                  border-green-600 text-green-600
                  items-center text-center">
        <p class="text-2xl text-center">SIMULATION COMPLETED</p>
        <a href={"/stats/#{@game_name}"}
        target="_blank"
        class="mt-2 border-2 rounded-md w-1/2
               border-gray-800 bg-green-400
               hover:shadow-outline hover:bg-green-600 hover:text-white">
      View Statistics
    </a>
      </div>
    """
  end

  def render_turn_instructions(assigns) do
    ~H"""
    <div class="w-1/2 flex-grow flex flex-col border-2 rounded-md
                border-gray-700
                text-sm text-center">
      <%= render_specific_instructions(assigns) %>
    </div>
    """
  end

  def render_specific_instructions(%{player: player} = assigns) do
    cond do
      player == nil ->
        render_observer_instructions(assigns)

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

  def render_done_instructions(assigns) do
    ~H"""
    <p class="text-gray-600">You are waiting for the other players to go</p>
    """
  end

  def render_help_instructions(assigns) do
    ~H"""
    <p class="text-base font-bold">Instructions</p>
    <p>You cannot move your own items so you can help someone!</p>
    <p class="font-black" >Unblock or move someone else's item</p>
    """
  end

  def render_reject_instructions(assigns) do
    ~H"""
    <p class="text-base font-bold">Instructions</p>
    <p>You have accepted an item</p>
    <p>Now you can reject any item on the board</p>
    <p class="font-black" >Discuss with the other players and reject an item</p>
    """
  end

  def can_class(actions) when length(actions) > 0, do: "font-black"
  def can_class(_), do: "text-gray-500"

  def render_black_instructions(assigns) do
    ~H"""
      <p class="text-base font-bold">Instructions</p>
      <p>You must both:</p>
      <p class={can_class(@options.block)} >block one unblocked item</p>
      <p class={can_class(@options.start)} >and start one new item</p>
    """
  end

  def render_red_instructions(assigns) do
    ~H"""
      <p class="text-base font-bold">Instructions</p>
      <p>You must either:</p>
      <p class={can_class(@options.move)} >move one of your unblocked items one column right</p>
      <p class={can_class(@options.unblock)} >or unblock one of your blocked items</p>
      <p class={can_class(@options.start)} >or start one new item</p>
    """
  end

  def helping?(%{hlp_mv: hlp_mv, hlp_unblk: hlp_unblk}) do
    not (Enum.empty?(hlp_mv) && Enum.empty?(hlp_unblk))
  end

  def rejecting?(%{reject: reject}), do: not Enum.empty?(reject)

  def render_other_player_state(assigns) do
    ~H"""
      <div class="flex-grow mx-1 w-1/12 flex flex-col">
        <%= for player <- Enum.reject(@players, fn p -> p.id == @player_id end) do %>
          <%= cond do %>
            <% player.state == :done -> %>
              <div class="h-8 mb-1 border-2 rounded-md border-gray-400 text-gray-400 text-center"><%= player.initials %></div>
            <% player.machine == :red -> %>
              <div class="h-8 mb-1 border-2 rounded-md border-red-700 text-red-700 text-center"><%= player.initials %></div>
            <% true -> %>
            <div class="h-8 mb-1 border-2 rounded-md border-black text-black text-center"><%= player.initials %></div>
          <% end %>
        <% end %>
      </div>
    """
  end

  def render_turn_display(%{player: player, day: day}) do
    cond do
      player == nil || day == 0 || player.state == :done ->
        render_non_turn_display(%{colour: "gray-400", nr: day})

      player.machine == :red ->
        render_red_turn_display(%{colour: "red-700", nr: day})

      true ->
        render_black_turn_display(%{colour: "black", nr: day})
    end
  end

  def render_non_turn_display(assigns) do
    ~H"""
      <div class="w-1/6 flex-grow border-2 rounded-md
                  border-gray-400
                  flex">
        <div class="w-1/4 flex flex-col">
        </div>
        <div class="w-2/4 flex flex-col justify-center">
          <div class="text-center text-gray-400 text-2xl">Day:</div>
          <div class="text-center text-gray-400 text-2xl">
            <%= to_string(@nr) %>
          </div>
        </div>
        <div class="w-1/4 flex flex-col flex-col-reverse">
        </div>
      </div>
    """
  end

  def render_black_turn_display(assigns) do
    ~H"""
      <div class="w-1/6 flex-grow border-2 rounded-md
                  border-black
                  flex">
        <div class="w-1/4 flex flex-col flex-col-reverse">
          <img class="p-1 object-contain" src={image("black_spade.svg")} alt="black spade">
        </div>
        <div class="w-2/4 flex flex-col justify-center">
          <div class="text-center text-black text-2xl">Day:</div>
          <div class="text-center text-black text-2xl">
            <%= to_string(@nr) %>
          </div>
        </div>
        <div class="w-1/4 flex flex-col">
          <img class="p-1 object-contain" src={image("black_club.svg")} alt="black club">
        </div>
      </div>
    """
  end

  def render_red_turn_display(assigns) do
    ~H"""
      <div class="w-1/6 flex-grow border-2 rounded-md
                  border-red-700
                  flex">
        <div class="w-1/4 flex flex-col">
          <img class="p-1 object-contain" src={image("red_diamond.svg")} alt="red diamond">
        </div>
        <div class="w-2/4 flex flex-col justify-center">
          <div class="text-center text-red-700 text-2xl">Day:</div>
          <div class="text-center text-red-700 text-2xl">
            <%= to_string(@nr) %>
          </div>
        </div>
        <div class="w-1/4 flex flex-col flex-col-reverse">
          <img class="p-1 object-contain" src={image("red_heart.svg")} alt="red heart">
        </div>
      </div>
    """
  end

  def render_score_display(assigns) do
    ~H"""
      <div class="w-1/6 flex-grow border-2 rounded-md
                  border-black text-black
                  flex flex-col text-2xl">
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

  def get_initials(owner_id, players) do
    i = Enum.find(players, &(&1.id == owner_id))

    case i do
      nil -> ""
      _ -> i.initials
    end
  end

  def card_scheme(%{type: :task, action: nil}), do: "bg-green-300 border-green-500 text-gray-500"
  def card_scheme(%{type: :task, action: _}), do: "bg-green-500 border-green-800"

  def card_scheme(%{type: :change, action: nil}),
    do: "bg-yellow-300 border-yellow-500 text-gray-500"

  def card_scheme(%{type: :change, action: _}), do: "bg-yellow-300 border-yellow-800"

  def block_scheme(nil), do: "bg-red-300"
  def block_scheme(_), do: "bg-red-500"

  def render_item_body(assigns) do
    ~H"""
      <div class="flex flex-col ml-1">
        <div class="text-sm font-bold"><%= @initials %></div>
      </div>
      <div class="w-4 flex flex-col">
        <div class="text-xs"><%= @id %></div>
        <%= if @blocked do %>
          <div class={[block_scheme(@action),
                       "transform rotate-45 font-black",
                       "animate-arrive",
                       "text-xs px-1"]}>
           B
          </div>
        <% end %>
      </div>
    """
  end

  def render_active_item(%{action: action} = assigns) when is_nil(action) do
    ~H"""
      <div class={[card_scheme(%{type: @type, action: @action}),
                  "flex justify-between border-2",
                  "animate-arrive",
                  "w-16 h-10 m-1"]}>
        <%= render_item_body(assigns) %>
      </div>
    """
  end

  def render_active_item(assigns) do
    ~H"""
      <div class={[card_scheme(%{type: @type, action: @action}),
                  "cursor-pointer flex justify-between border-2 w-16 h-10 m-1",
                  "animate-arrive",
                  "hover:shadow-xl transform hover:-translate-y-px hover:-translate-x-px"]}
          phx-click="move"
          phx-value-type={@action}
          phx-value-id={@id}>
          <%= render_item_body(assigns) %>
      </div>
    """
  end

  @doc """
  Finds the items for the given state id then iterates over them and passes each to
  render_active_item/1
  """
  def active_items(assigns, state_id) do
    ~H"""
      <div class="flex flex-wrap">
        <%= if @state == :day || @state == :night do %>
          <%= for item <- Map.get(assigns.items, state_id, []) do %>
            <%= collect_item_data(item, assigns.players, @player) |> render_active_item() %>
          <% end %>
        <% end %>
      </div>
    """
  end

  def completed_items(assigns, state_id) do
    ~H"""
    <div class="flex flex-wrap">
      <%= for item <- Map.get(assigns.items, state_id, []) do %>
        <div class={[card_scheme(%{type: item.type, action: nil}),
                    "border-2 animate-arrive w-5 h-8 mt-1 ml-1"]}></div>
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
    ~H"""
    <div class="col-start-1 row-start-1 row-span-2 border border-gray-800">Agree Urgency</div>
    <div class="col-start-2 col-span-3 row-start-1 border border-gray-800 py-0">
      <p>In progress</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">
          WIP: <%= calculate_wip_for_state(@items, [1,2,3]) %>
        </div>
        <%= if is_wip_type?(@wip_limits, :cap) do %>
          <div class="col-start-2 row-start-1">
            Limit: <%= wip_limit(@wip_limits) %>
          </div>
        <% end %>
      </div>
     </div>
    <div class="col-start-5 col-span-4 row-start-1 row-span-2 border border-gray-800">Complete</div>

    <div class="col-start-2 row-start-2 border border-gray-800">
      <p>Negotiate Change</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">
          WIP: <%= calculate_wip_for_state(@items, [1]) %>
        </div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">
            Limit: <%= wip_limit(@wip_limits) %>
          </div>
        <% end %>
      </div>
    </div>
    <div class="col-start-3 row-start-2 border border-gray-800">
      <p>Validate Adoption</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">
          WIP: <%= calculate_wip_for_state(@items,[2]) %>
        </div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">
            Limit: <%= wip_limit(@wip_limits) %>
          </div>
        <% end %>
      </div>
    </div>
    <div class="col-start-4 row-start-2 border border-gray-800">
      <p>Verify Performance</p>
      <div class="grid place-items-center">
        <div class="col-start-1 row-start-1">
          WIP: <%= calculate_wip_for_state(@items, [3]) %>
        </div>
        <%= if is_wip_type?(@wip_limits, :std) do %>
          <div class="col-start-2 row-start-1">
            Limit: <%= wip_limit(@wip_limits) %>
          </div>
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
end
