# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  def project do
    [
      app: :skitter,
      name: "Skitter",
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      # Dev tools
      {:distillery, "~> 2.0", runtime: false},
      {:ex_doc, "~> 0.19.0", only: :dev, runtime: false},
      {:credo, "~> 0.10.0", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
