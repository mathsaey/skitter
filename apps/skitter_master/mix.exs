# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")
    [app: :skitter_master, deps: deps()] ++ global
  end

  def application do
    [
      mod: {Skitter.Master.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # TODO: Probably needs DSL/utils, only in dev
      {:skitter_core, in_umbrella: true},
      {:skitter_runtime, in_umbrella: true}
    ]
  end
end