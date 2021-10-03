defmodule Changeban.Presence do
  @moduledoc """
  Create a presence service
  """
  use Phoenix.Presence,
    otp_app: :games_room,
    pubsub_server: Changeban.PubSub
end
