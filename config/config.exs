use Mix.Config

# Load environment specific configuration
import_config "#{Mix.env()}.exs"

# We use a unified logging output for every skitter application.
config :logger, :console,
  format: "\n[$time][$metadata][$level$levelpad] $message\n",
  metadata: [:application, :file, :line]
