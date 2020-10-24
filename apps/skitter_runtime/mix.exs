# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")

    [
      app: :skitter_runtime,
      deps: deps(),
      # compilers: compilers(),
      # rustler_crates: rustler_crates(),
      elixirc_paths: elixirc_paths(Mix.env())
    ] ++ global
  end

  def application do
    [
      mod: {Skitter.Runtime.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:skitter_core, in_umbrella: true}
      # {:rustler, "~> 0.21.1"}
    ]
  end

  defp compilers, do: [:rustler] ++ Mix.compilers()

  defp rustler_crates do
    [skitter_buffer: [mode: if(Mix.env() == :prod, do: :release, else: :debug)]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
