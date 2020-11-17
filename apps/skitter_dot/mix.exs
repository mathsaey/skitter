# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Dot.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")

    [
      app: :skitter_dot,
      deps: deps(),
      config_path: "../../config/config.exs"
    ] ++ global
  end

  def application do
    [
      extra_applications: [:eex]
    ]
  end

  defp deps do
    [
      {:skitter_core, in_umbrella: true}
    ]
  end
end
