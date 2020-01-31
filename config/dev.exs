import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :stamper, StamperWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Локальные настройки (пути к файлам, java-приложению).
# Файл local.exs не коммитится, создайте его по образцу local.exs.example
import_config "local.exs"
