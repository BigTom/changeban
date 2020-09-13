defmodule GamesRoomWeb.SessionController do
  use GamesRoomWeb, :controller

  def set(conn, %{"username" => username}), do: store_string(conn, :username, username)
  def set(conn, %{"color" => color}), do: store_string(conn, :color, color)
  def set(_conn, s), do: IO.puts("No known value in: #{inspect s}}")

  defp store_string(conn, key, value) do
    IO.puts("SessionController.store_string - k: #{key} - v: #{value} ---------------------------------------" )
    conn
    |> put_session(key, value)
    |> json("OK!")
  end
end
