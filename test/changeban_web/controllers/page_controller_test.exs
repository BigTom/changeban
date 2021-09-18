defmodule ChangebanWeb.PageControllerTest do
  use ChangebanWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "<p>Changeban is a Lean Startup-flavoured Kanban simulation game.</p>"
  end
end
