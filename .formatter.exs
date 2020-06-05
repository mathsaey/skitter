# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Use the same formatting rules for all applications which are not specifically
# excluded.

exlude = [:dsl]

inputs =
  Mix.Project.apps_paths()
  |> Enum.reject(fn {key, _} -> key in exlude end)
  |> Enum.map(fn {_, path} -> "#{path}/{lib,test}/**/*.{ex, exs}" end)
  |> (fn inputs -> ["mix.exs", "config/*.exs"] ++ inputs end).()

subdirectories =
  Mix.Project.apps_paths()
  |> Enum.filter(fn {key, _} -> key in exlude end)
  |> Enum.map(fn {_, path} -> path end)

[
  inputs: inputs,
  subdirectories: subdirectories,
  locals_without_parens: [
    throw: :*,
  ]
]
