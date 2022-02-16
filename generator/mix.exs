# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule SkitterNew.MixProject do
  use Mix.Project

  def project do
    skitter_project = Mix.Project.in_project(:skitter, "../", &(&1.project()))
    [
      app: :skitter_new,
      version: skitter_project[:version],
      elixir: skitter_project[:elixir],
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:eex]
    ]
  end
end
