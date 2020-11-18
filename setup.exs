# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Shared configuration for building child projects in the Skitter umbrella. Since mix is not
# available when this module is needed, this module should be required as follows:
#   `Code.require_file("../../setup.exs")`

defmodule Setup do
  @default_opts [
    elixir: "~> 1.11",
    version: File.read!("#{__DIR__}/VERSION.txt") |> String.trim(),
    start_permanent: Mix.env() == :prod,
    lockfile: "#{__DIR__}/mix.lock",
    deps_path: "#{__DIR__}/deps",
    build_path: "#{__DIR__}/_build"
  ]

  defp project(app, extra), do: [app: app] ++ Keyword.merge(@default_opts, extra)

  def lib(app, extra \\ []) do
    project(app, extra) ++ [config_path: "#{__DIR__}/config/config.exs"]
  end

  def rel(app, extra \\ []) do
    project(app, extra) ++ [config_path: "config/config.exs"]
  end
end
