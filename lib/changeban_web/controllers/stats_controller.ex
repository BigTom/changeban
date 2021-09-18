defmodule ChangebanWeb.StatsController do
  use ChangebanWeb, :controller

  def stats(conn, _params) do
    render(conn, "stats.html", name: "Test")
  end
end
