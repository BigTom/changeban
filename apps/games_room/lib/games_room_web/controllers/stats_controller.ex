defmodule GamesRoomWeb.StatsController do
  use GamesRoomWeb, :controller

  def stats(conn, _params) do
    render(conn, "stats.html", name: "Test")
  end
end
