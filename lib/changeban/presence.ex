defmodule Changeban.Presence do
  use Phoenix.Presence,
    otp_app: :games_room,
    pubsub_server: Changeban.PubSub
end
