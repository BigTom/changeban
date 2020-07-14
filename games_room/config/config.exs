# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :games_room, GamesRoomWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "lfj97Il+h5FF7Eevq9z0GsJ8jvMScry2+iswrT9xC3oPzf2OXGbYVKuB2jHUonjF",
  render_errors: [view: GamesRoomWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GamesRoom.PubSub,
  live_view: [signing_salt: "bg8IFl8ULBRkQFCL8ny2ssXM+5F+wH6L"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
