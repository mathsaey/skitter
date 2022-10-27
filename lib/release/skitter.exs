# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

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

config_from_env :tags, "SKITTER_TAGS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end

# Master
config_from_env :workers, "SKITTER_WORKERS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end

config_enabled_if_set :shutdown_with_workers, "SKITTER_SHUTDOWN_WITH_WORKERS"

# Master & Local
config_from_env :deploy, "SKITTER_DEPLOY", fn str ->
  fn ->
    case Code.eval_string(str) do
      {wf = %Skitter.Workflow{}, _} -> wf
      {val, _} -> raise "Evaluating `#{str}` returned `#{inspect(val)}`, expected a workflow."
    end
  end
end

# Logging
if System.get_env("SKITTER_LOG") do
  file = "#{System.fetch_env!("RELEASE_NODE")}.log"
  dir = File.cwd!() |> Path.join("logs")
  File.mkdir_p!(dir)

  config :logger, backends: [:console, {LoggerFileBackend, :file_log}]

  console_config = Application.get_env(:logger, :console, [])

  config :logger, :file_log,
    path: Path.join(dir, file),
    level: console_config[:level] || :info,
    format: console_config[:format] || "[$time][$level]$metadata $message\n",
    metadata: console_config[:metadata] || []
end
