use Mix.Config

# Remove all logging except warnings and errors in production
config :logger, compile_time_purge_level: :warn
