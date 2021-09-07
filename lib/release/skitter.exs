# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runtime configuration of the Skitter release.
# This file is copied over into any skitter release and read before the application is started.
# It configures Skitter based on environment variables set by the skitter deploy script.

import Skitter.Release.Config
import Config

config_from_env :mode, "SKITTER_MODE", &String.to_atom/1

# Worker
config_from_env :master, "SKITTER_MASTER", &String.to_atom/1
config_enabled_unless_set :shutdown_with_master, "SKITTER_NO_SHUTDOWN_WITH_MASTER"

# Master
config_from_env :workers, "SKITTER_WORKERS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end

# Master & Local
config_from_env :deploy, "SKITTER_DEPLOY", fn str ->
  [mod, func] = str |> String.split(".")
  mod = Module.safe_concat([mod])
  func = String.to_existing_atom(func)
  {mod, func, []}
end

# Logging
if System.get_env("SKITTER_LOG") do
  file = "#{System.fetch_env!("RELEASE_NODE")}.log"
  dir = File.cwd!() |> Path.join("logs")
  File.mkdir_p!(dir)

  config :logger, backends: [:console, {LoggerFileBackend, :file_log}]
  config :logger, :file_log, path: Path.join(dir, file), level: :info
end
