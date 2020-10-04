defmodule GamesRoomWeb.PageLiveTest do
  use GamesRoomWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "two character initials"
    assert render(page_live) =~ "two character initials"
  end
end
