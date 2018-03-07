# config.prod.exs
# Mathijs Saey

# This file contains the skitter production configuration.
use Mix.Config

# Remove all logging except errors in production
config :logger,
  compile_time_purge_level: :error
