# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :stamper, StamperWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OybEkBKg4tvChX8Igi/6vNx1FCR3IHKL9ljMZhXK2mdxbYMv3VGo/kKc9CsGoua9",
  render_errors: [view: StamperWeb.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config.
import_config "#{config_env()}.exs"
