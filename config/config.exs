# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

config :games_room,
  generators: [context_app: :changeban]

# Configures the endpoint
config :games_room, GamesRoomWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "BdHJDtzWRriJaoasX3vyV9qdZIbYZfyEy270Yd2a2v+CrPpsA8Io8UMgHqPv4MIa",
  render_errors: [view: GamesRoomWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GamesRoom.PubSub,
  live_view: [signing_salt: "M9Ve8fvhUAY0WPRgjJz84yWpNoCdZY4j"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
