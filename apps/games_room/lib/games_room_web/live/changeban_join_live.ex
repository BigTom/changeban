defmodule GamesRoomWeb.ChangebanJoinLive do
  require Logger
  use GamesRoomWeb, :live_view

  alias Phoenix.LiveView
  alias Changeban.{GameServer, GameSupervisor}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, game_name: nil)}
  end


  @impl true
  def handle_event(
        "join_game",
        %{"initials" => supplied_initials, "game_name" => supplied_game_name},
        supplied_socket
      ) do
    Logger.debug("joining  existing game")
    socket = LiveView.clear_flash(supplied_socket)
    initials = String.trim(supplied_initials) |> String.upcase
    game_name = String.trim(supplied_game_name) |> String.upcase
    Logger.debug("adding player: #{inspect(initials)} to existing game: #{inspect(game_name)}")

    cond do
      String.length(game_name) == 0 ->
        Logger.info("Non existant game")
        {:noreply,
          LiveView.put_flash(socket, :error, "No game name supplied")}

      String.length(initials) == 0 ->
        Logger.info("Non existant game")
        {:noreply,
          LiveView.put_flash(socket, :error, "No initials supplied")}

      GameServer.joinable?(game_name) ->
        Logger.debug("Allow player to join game: #{game_name}")
        {:ok, player_id, _player} = GameServer.add_player(game_name, initials)
        {:noreply,
          LiveView.push_redirect(socket, to: "/game/#{game_name}/#{player_id}/#{initials}",
          replace: true)}

      GameServer.game_exists?(game_name) ->
        Logger.debug("Allow player to view game game: #{game_name}")
        {:noreply,
          LiveView.push_redirect(socket, to: "/game/#{game_name}",
          replace: true)}

      true ->
        Logger.info("Non existant game")
        {:noreply,
          LiveView.put_flash(socket, :error, "Game #{game_name} does not exist")}
    end
  end

  @impl true
  def handle_event(
        "new_game",
        %{"initials" => supplied_initials, "wip" => supplied_wip_type},
        supplied_socket
      ) do
    Logger.debug("event new_game")
    socket = LiveView.clear_flash(supplied_socket)
    initials = String.trim(supplied_initials) |> String.upcase

    cond do
      String.length(String.trim initials) == 0 ->
        Logger.info("Non existant game")
        {:noreply,
          LiveView.put_flash(socket, :error, "No initials supplied")}

      true ->
        game_name = gen_game_name()
        wip_type = String.to_existing_atom(supplied_wip_type)

        Logger.debug(
          "new_game: #{inspect(game_name)} with WIP limit type #{wip_type} and player: #{initials}"
        )

        GameSupervisor.create_game(game_name)
        GameServer.set_wip(game_name, wip_type, 2)
        {:ok, player_id, _player} = GameServer.add_player(game_name, initials)
        {:noreply,
          LiveView.push_redirect(socket, to: "/game/#{game_name}/#{player_id}/#{initials}",
          replace: true)}
    end
  end

  @impl true
  def handle_info(evt, socket) do
    Logger.warn("**** UNKNOWN-EVENT #{inspect(evt)}")
    {:noreply, socket}
  end

  defp gen_game_name() do
    chars = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789"
    end_index = String.length(chars) - 1
    List.to_string(for _n <- 0..5, do: String.at(chars, Enum.random(0..end_index)))
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="flex h-screen">
      <div class="w-1/2 flex flex-1 overflow-y-scroll">
        <article class="prose lg:prose-sm">
          <h1>Instructions</h1>
          <p>Changeban is a Lean Startup-flavoured Kanban simulation game.</p>
          <p>It was created by Mike Burrows, the founder of
            <a class="text-gray-700 underline" href="https://www.agendashift.com" target="_blank">Agendashift</a>,
            as an in-person workshop game.  To understand the objectives and outcomes of playing the
            game have a look at the
            <a class="text-gray-700 underline" href="https://www.agendashift.com/resources/changeban" target="_blank">Changeban</a>
            page, on the Agendashift site.</p>
            <p>In this online version you will see what type of turn you have and what you can do.  The game will
            not allow you to make an invalid move.  Simply look at the bold tickets and pick one.  Clicking
            on it will make the move.</p>
            <p>When played in person randomness is introduced for play by each player drawing a card,
            which could be red or black. Here the game will deal your colour for you.</p>
            <h2>For a RED Card</h2>
            <li>EITHER advance one of your unblocked items one column rightwards</li>
            <li>OR unblock one of your blocked items by crossing out its ‘B’ mark</li>
            <li>OR start a new item if any remain - move it to the first in-progress column</li>
            <li>If and only if you can’t make one of these moves for yourself, help someone! Advance
                or unblock another player’s item Whenever you accept an item, reject another, chosen
                by the whole team</li>
          <h2>For a BLACK Card</h2>
          <p>After your daily standup meeting:</p>
          <li>BOTH block one of your currently unblocked items if you have any</li>
          <li>AND start a new item if any remain – even if you had nothing to block</li>
          <li>If and only if you can’t <i>start a new item</i>, help someone! Advance or unblock another
              player’s item.</li>
          <h2>Rejecting Items</h2>
          <p>Whether you are playing a red or black turn whenever you accept an item, reject another,
            chosen by the whole team</p>
          <h2>Scoring</h2>
          <p>Changeban simulates the idea that many of our ideas will be rejected as we find out about them.
            There are two colours of items representing different kinds of work.  To maimise the team's score
            There should be a balance of completeion and rejection and a balance of types of work.</p>
          <li>1 point for each Accepted item, up to a maximum of 4 per colour – 8 points available</li>
          <li>1 point for each colour represented in each subcolumn of Rejected – 8 points available</li>
          <li>A bonus point for each subcolumn of Rejected that contains exactly 2 items, 1 of each colour –
            4 points available</li>
          <p>The maximum score is 20</p>
          <h2>Playing Multiple Games</h2>
          <p>You cannot restart a game but you can play as many times as you like, simply start a new game.</p>
          <h2>Limiting WIP</h2>
          <p>The game can be played without WIP limits, with a limit for each column or a consolidated
            limit across all the in-progress columns.  Simple check the appropriate box when creating a game.</p>
          <p>After you have started a game the six character game name is displayed in the bottom left
            corner.  Pass this on to the players for them to join.</p>
          <p>Each game can hold a maximum of 5 players and you cannot join after it has begun.
            If you try to join a full, or running game you will be given the opportunity to watch it play."</p>
        </article>
      </div>
      <div class="w-1/2 rounded shadow px-2 b-1 m-4">
        <article class="prose lg:prose-sm">
          <h2>Do you want to join a game?</h2>
          <p>Enter your 6 character game name, your one or two character initials and click "Join Game"</p>
          <p>Each game can hold a maximum of 5 players and you cannot join after it has begun.
          If you try to join a full, or running game you will be given the opportunity to watch it play."</p>
       </article>
        <form phx-submit="join_game" class="py-4">
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
          <article class="prose lg:prose-sm">
          </article>
        </form>
        <article class="prose lg:prose-sm">
          <h2>Or start a new one?</h2>
          <p>Enter your one or two character initials, select your Work in Progress (WIP) limit type and click "New Game"</p>
        </article>
        <form phx-submit="new_game" class="py-4">
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
        <article class="prose lg:prose-sm">
          <p>The game can be played without WIP limits, with a limit for each column or a consolidated
             limit across all the in-progress columns.  Simple check the appropriate box when creating a game.</p>
          <p>After you have started a game the six character game name is displayed in the bottom left
            corner.  Pass this on to the players for them to join.</p>
        </article>
      </div>
    </div>
    """
  end
end
