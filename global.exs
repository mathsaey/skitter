# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Shared configuration for the child projects in the Skitter umbrella.
# Eval with `Code.eval`

[
  elixir: "~> 1.10",
  version: File.read!("#{__DIR__}/VERSION.txt") |> String.trim(),
  start_permanent: Mix.env() == :prod,
  lockfile: "#{__DIR__}/mix.lock",
  deps_path: "#{__DIR__}/deps",
  build_path: "#{__DIR__}/_build",
  config_path: "#{__DIR__}/config/config.exs",
]
