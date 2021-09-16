# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  def project do
    [
      app: :skitter,
      name: "Skitter",
      elixir: "~> 1.12",
      version: "0.5.0-dev",
      source_url: "https://github.com/mathsaey/skitter/",
      homepage_url: "https://soft.vub.ac.be/~mathsaey/skitter/",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(),
      deps: deps(),
      docs: docs(),
      xref: xref()
    ]
  end

  def application do
    [
      mod: {Skitter.Runtime.Application, []},
      start_phases: [sk_welcome: [], sk_connect: [], sk_deploy: []],
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      # Dev
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},

      # Runtime
      {:logger_file_backend, "~> 0.0.12"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "builtin", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      plt_add_apps: [:mix, :iex, :eex],
      plt_local_path: "_build/dialyzer/"
    ]
  end

  defp xref do
    [exclude: IEx]
  end

  defp docs do
    [
      main: "readme",
      assets: "assets",
      extras: ["README.md"],
      authors: ["Mathijs Saey"],
      api_reference: false,
      source_ref: "develop",
      logo: "assets/logo-light_docs.png",
      formatters: ["html"],
      groups_for_modules: [
        "Language Abstractions": [
          Skitter.Port,
          Skitter.Component,
          Skitter.Workflow,
          Skitter.Strategy
        ],
        "Runtime Hooks": ~r/Skitter.Strategy\..*/,
        "Runtime Constructs": [
          Skitter.Manager,
          Skitter.Worker,
          Skitter.Deployment,
          Skitter.Invocation,
          Skitter.Nodes
        ],
        dsl: ~r/Skitter.DSL*/,
        "Built-in Components": ~r/Skitter.BIC.*/,
        "Built-in Strategies": ~r/Skitter.BIS.*/,
        utilities: [
          Skitter.Dot
        ]
      ]
    ]
  end
end
