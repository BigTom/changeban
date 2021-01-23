defmodule Changeban.Game do
  require Logger

  @moduledoc """
  Manages the game state.

  A game has:
    players - list of players how can own items
    items - map of item_ids to items
    day   - today's number
    state - current state of game
            setup
            running (day|night)
            done


  Score:
    1 per accepted item up to 4 for each color e.g. max 8
    1 point per type in each rejected column e.g. max 8
    1 point for each rejected column with 1 and only one of EACH color e.g. max 4

    Total possible 20

  future
    moves - the list of :red and :black moves
  """
  @states 0..8
  @max_player_id 4
  @turn_cycle 100
  @no_wip_limits %{1 => true, 2 => true, 3 => true}

  @enforce_keys [:items]
  defstruct players: [],
            max_players: 0,
            items: [],
            score: 0,
            day: 0,
            state: :setup,
            wip_limits: {:none, 0},
            turns: [],
            history: []

  # Valid wip limits:
  # {:none, 0} - default
  # {:std, [n,n,n]}
  # {:agg, n}

  alias Changeban.{Game, Item, ItemHistory, Player}

  def states() do
    %{
      0 => "Agree Urgency",
      1 => "Negotiate Change",
      2 => "Validate Adoption",
      3 => "Verify Performance",
      4 => "Complete",
      5 => "Rejected - Agree Urgency",
      6 => "Rejected - Negotiate Change",
      7 => "Rejected - Validate Adoption",
      8 => "Rejected - Verify Performance"
    }
  end

  def new() do
    %Game{items: initial_items(16), max_players: @max_player_id + 1, turns: turns()}
  end

  def new_short_game_for_testing() do
    %Game{items: initial_items(4), max_players: @max_player_id + 1, turns: turns()}
  end

  def initial_items(nr_items), do: for(id <- 0..(nr_items - 1), do: Item.new(id))

  def turns() do
    for _ <- 0..(@turn_cycle - 1), do: Enum.random([:red, :black])
  end

  def add_player(%Game{players: players} = game, initials) do
    new_player_id = player_count(game)

    if new_player_id <= @max_player_id do
      new_player = Player.new(new_player_id, initials)
      {:ok, new_player_id, %{game | players: [new_player | players]}}
    else
      {:error, "Already at max players"}
    end
  end

  def remove_player(%Game{players: players, items: items} = game, player_id) do
    new_players = Enum.reject(players, &(&1.id == player_id))

    if running?(game) && Enum.count(new_players) > 0 do
      items_to_reassign =
        items
        |> Enum.filter(&(&1.owner == player_id))

      players_to_assign =
        new_players
        |> Enum.map(& &1.id)
        |> Enum.take(Enum.count(items))
        |> Stream.cycle()
        |> Enum.take(Enum.count(items_to_reassign))

      reassigned_items =
        Enum.zip(players_to_assign, items_to_reassign)
        |> Enum.map(fn {player_id, item} -> %{item | owner: player_id} end)

      new_items =
        Enum.sort_by(Enum.reject(items, &(&1.owner == player_id)) ++ reassigned_items, & &1.id)

      %{game | players: new_players, items: new_items}
      |> recalculate_state
    else
      %{game | players: new_players}
    end
  end

  def joinable?(%Game{state: state} = game) do
    state == :setup &&
      player_count(game) < @max_player_id + 1
  end

  def running?(%Game{state: state}), do: state == :day || state == :night

  def player_count(%Game{players: players}) do
    Enum.count(players)
  end

  def start_game(%Game{players: []}), do: {:error, "No players"}
  def start_game(%Game{day: 0, state: :setup} = game), do: new_day(%{game | state: :day})
  def start_game(game), do: game

  def new_day(%Game{state: :done} = game), do: game

  def new_day(%Game{players: players, day: day} = game) do
    new_game = update_history(game)

    cond do
      game_over?(new_game) ->
        %{new_game | state: :done}

      all_blocked?(new_game) ->
        %{
          new_game
          | players: Enum.map(players, &Player.set_player(&1, :red, :act, nil)),
            day: day + 1
        }
        |> recalculate_state

      true ->
        %{
          new_game
          | players:
              Enum.map(
                players,
                &Player.set_player(&1, red_or_black(new_game, &1.id, day), :act, nil)
              ),
            day: day + 1
        }
        |> recalculate_state
    end
  end

  def red_or_black(%Game{turns: turns, players: players}, player_id, day) do
    position = rem(day * Enum.count(players) + player_id, @turn_cycle)
    Enum.at(turns, position)
  end

  # || game_over_single_player_blocked(game)
  def game_over?(game), do: game_over_all_done(game)

  def game_over_all_done(%Game{items: items}) do
    Enum.find(items, &Item.active?/1) == nil
  end

  @doc """
    One player, all active items are blocked
  """
  def all_blocked?(%Game{items: items, players: players}) do
    active =
      items
      |> Enum.filter(&Item.active?/1)
      |> Enum.reject(&Item.blocked?/1)
      |> Enum.count()

    active == 0 && Enum.count(players) == 1
  end

  def get_item(%Game{items: items}, id) do
    items |> Enum.find(&(&1.id == id))
  end

  def update_game(
        %Game{items: items, players: players} = game,
        %Item{} = item,
        %Player{} = player
      ) do
    items_ =
      items
      # Take out existing version
      |> Enum.filter(&(&1.id != item.id))
      # insert new version
      |> List.insert_at(0, item)
      # make sure the order is maintained
      |> Enum.sort_by(& &1.id)

    players_ =
      players
      # Take out existing version
      |> Enum.filter(&(&1.id != player.id))
      # insert new version
      |> List.insert_at(0, player)
      # make sure the order is maintained
      |> Enum.sort_by(& &1.id)

    game_ = %{game | items: items_, players: players_}
    recalculate_state(game_)
  end

  def recalculate_state(game) do
    score = calculate_score(game)
    players = recalculate_all_player_options(game)

    game_ = %{game | score: score, players: players}

    case Enum.find(players, &(&1.state != :done)) do
      nil -> new_day(game_)
      _ -> game_
    end
  end

  def calculate_score(%Game{items: items}) do
    score_for_completed(items) +
      Enum.sum(for s <- 5..8, do: score_for_rejected(items, s))
  end

  def score_for_completed(items) do
    task_score =
      Enum.filter(items, &(&1.state == 4 && &1.type == :task)) |> Enum.count() |> min(4)

    change_score =
      Enum.filter(items, &(&1.state == 4 && &1.type == :change)) |> Enum.count() |> min(4)

    task_score + change_score
  end

  def score_for_rejected(items, state) do
    task_score = Enum.filter(items, &(&1.state == state && &1.type == :task)) |> Enum.count()
    change_score = Enum.filter(items, &(&1.state == state && &1.type == :change)) |> Enum.count()
    score = min(task_score, 1) + min(change_score, 1)
    bonus = if task_score == 1 && change_score == 1, do: 1, else: 0
    score + bonus
  end

  def recalculate_all_player_options(%Game{players: players, items: items} = game) do
    below_wip_limits = wip_limited_states(game)
    Enum.map(players, &Player.calculate_player_options(items, &1, below_wip_limits))
  end

  def get_player(%Game{players: players}, player_id),
    do: Enum.find(players, &(&1.id == player_id))

  def exec_action(%Game{day: day} = game, act, item_id, player_id) do
    item = Game.get_item(game, item_id)
    player = Game.get_player(game, player_id)

    if player.state == :done do
      Logger.warn("Tried to make a move in :done state")
      game
    else
      {item_, player_} = action(act, item, player, day)
      update_game(game, item_, player_)
    end
  end

  def action(:unblock, item, player, day),
    do: {Item.unblock(item, day), Player.turn_done(player)}

  def action(:hlp_unblk, item, player, day),
    do: {Item.help_unblock(item, day), Player.turn_done(player)}

  def action(:reject, item, player, day), do: {Item.reject(item, day), Player.turn_done(player)}

  def action(:start, item, %Player{machine: machine} = player, day) do
    player_ =
      case machine do
        :red ->
          Player.turn_done(player)

        :black ->
          case player.past do
            :blocked -> %{player | state: :done, past: nil}
            _ -> %{player | past: :started}
          end
      end

    {Item.start(item, player.id, day), player_}
  end

  def action(:block, item, player, day) do
    player_ =
      case player.past do
        :started -> %{player | state: :done, past: nil}
        _ -> %{player | past: :blocked}
      end

    {Item.block(item, player.id, day), player_}
  end

  def action(:move, item, player, day) do
    item_ = Item.move_right(item, day)
    {item_, move_done(item_, player)}
  end

  def action(:hlp_mv, item, player, day) do
    item_ = Item.help_move_right(item, day)
    {item_, move_done(item_, player)}
  end

  def action(act, _, _, _), do: raise("invalid action: #{inspect(act)}")

  def move_done(item, player) do
    if Item.complete?(item) do
      %{player | past: :completed}
    else
      Player.turn_done(player)
    end
  end

  # WIP Limit Management
  # Valid wip limits:
  # {:none, 0} - default
  # {:std, [n,n,n]}
  # {:agg, n}

  def set_wip(game, :none, _), do: %{game | wip_limits: {:none, 0}}
  def set_wip(game, :std, limit), do: %{game | wip_limits: {:std, limit}}
  def set_wip(game, :agg, limit), do: %{game | wip_limits: {:agg, limit}}

  def wip_limited_states(%Game{wip_limits: {:none, _}}), do: @no_wip_limits

  def wip_limited_states(%Game{items: items, wip_limits: {:std, limit}}) do
    Map.new([1, 2, 3], fn state_id ->
      {state_id, limit > item_count_for_state(items, state_id)}
    end)
  end

  # conwip stops you starting
  def wip_limited_states(%Game{items: items, wip_limits: {:agg, limit}}) do
    c = Enum.map([1, 2, 3], &item_count_for_state(items, &1)) |> Enum.sum()

    cond do
      limit == 0 ->
        Logger.warn("Tried to set 0 conwip")
        @no_wip_limits

      limit > c ->
        @no_wip_limits

      true ->
        %{1 => false, 2 => true, 3 => true}
    end
  end

  def state_wip_open?(items, state_id, limit) do
    limit > item_count_for_state(items, state_id)
  end

  def item_count_for_state(items, state_id) do
    Enum.group_by(items, & &1.state)
    |> Map.get(state_id, [])
    |> Enum.count()
  end

  # History - CFD
  def state_counts(items),
    do: for(id <- @states, into: %{}, do: {id, item_count_for_state(items, id)})

  def create_history_line(items, day),
    do: ["#{day}" | for(x <- 8..0, into: [], do: Map.get(items, x))]

  def add_line(new_line, history), do: [new_line | Enum.reverse(history)] |> Enum.reverse()

  def update_history(%Game{items: items, history: history, day: day} = game) do
    new_state_history =
      state_counts(items)
      |> create_history_line(day)
      |> add_line(history)

    %{game | history: new_state_history}
  end

  def ages(items) do
    Enum.map(items, & &1.history)
    |> Enum.filter(&(!is_nil(&1.done)))
    |> Enum.map(&%{x: &1.done, y: ItemHistory.age(&1, 0)})
  end

  def efficency(items) do
    sum = Enum.map(items, fn i -> ItemHistory.efficency(i.history) end) |> Enum.sum()
    count = Enum.count(items)
    sum / count
  end

  def block_count(items) do
    Enum.map(items, fn i -> ItemHistory.block_count(i.history) end) |> Enum.sum()
  end

  def help_count(items) do
    Enum.map(items, fn i -> ItemHistory.help_count(i.history) end) |> Enum.sum()
  end

  def stats(%Game{state: state, items: items, players: players} = game) do
    stats =
      if state == :setup do
        %{
          turns: [["-", 0, 0, 0, 0, 0, 0, 0, 0, 0]],
          ticket_ages: [],
          median_age: 0,
          efficiency: 0,
          block_count: 0,
          help_count: 0,
          day: 0,
          score: 0,
          players: Enum.count(players)
        }
      else
        %{
          turns: game.history,
          ticket_ages: Item.ages(items),
          efficiency: Item.efficency(items),
          median_age: Item.median_age(items),
          block_count: Item.block_count(items),
          help_count: Item.help_count(items),
          day: game.day,
          score: game.score,
          players: Enum.count(players),
          wip_limits: game.wip_limits
        }
      end

    stats
  end
end
