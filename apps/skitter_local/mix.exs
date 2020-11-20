# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Local.MixProject do
  Code.require_file("../../setup.exs")
  use Mix.Project

  def project do
    Setup.rel(
      :skitter_local,
      deps: deps(),
      release_opts: [
        overlays: ["#{Setup.root()}/rel/iex/"]
      ]
    )
  end

  def application do
    [
      mod: {Skitter.Local.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:skitter_application, in_umbrella: true},
      {:skitter_core, in_umbrella: true},
      {:skitter_dsl, in_umbrella: true},
      {:skitter_dot, in_umbrella: true}
    ]
  end
end
