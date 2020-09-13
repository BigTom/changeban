defmodule GamesRoom.Presence do
  use Phoenix.Presence,
    otp_app: :games_room,
    pubsub_server: GamesRoom.PubSub
end
