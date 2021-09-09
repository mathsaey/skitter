# This file is used by mix to configure your application before it is compiled.
# In here, we only configure the erlang logger.
# You are free to delete or modify this file.

import Config

config :logger, :console,
  format: "\n[$time][$level$levelpad] $message",
  device: :standard_error,
  metadata: :all

# Remove all log messages with a priority lower than info at compile time if we are creating a
# production build.
case Mix.env() do
  :prod ->
    config :logger, :console, compile_time_purge_matching: [[level_lower_than: :info]]
  _ ->
    nil
end
