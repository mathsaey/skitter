# config.exs
# Mathijs Saey

# This file contains the configuration common to all skitter apps.
use Mix.Config

# Import application and environment specific config.
import_config "../apps/*/config/config.exs"
import_config "config.#{Mix.env}.exs"

# We use a unified logging output for every skitter application.
config :logger, :console,
  format: "\n[$time][$metadata][$level$levelpad] $message\n",
  metadata: [:application,:file,:line]
