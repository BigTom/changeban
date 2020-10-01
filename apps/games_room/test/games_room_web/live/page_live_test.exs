defmodule GamesRoomWeb.PageLiveTest do
  use GamesRoomWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Please enter an initial"
    assert render(page_live) =~ "Please enter an initial"
  end
end
