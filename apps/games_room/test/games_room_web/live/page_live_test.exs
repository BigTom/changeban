defmodule GamesRoomWeb.PageLiveTest do
  use GamesRoomWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Turn:"
    assert render(page_live) =~ "Turn:"
  end
end
