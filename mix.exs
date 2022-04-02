# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  # Be sure to update generator/mix.exs when updating this file!

  @github_url "https://github.com/mathsaey/skitter/"
  @home_url "https://soft.vub.ac.be/~mathsaey/skitter/"

  def project do
    [
      app: :skitter,
      name: "Skitter",
      elixir: "~> 1.13",
      version: "0.6.0-dev",
      source_url: @github_url,
      homepage_url: @home_url,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      dialyzer: dialyzer(),
      package: package(),
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
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},

      # Runtime
      {:logger_file_backend, "~> 0.0.13"},
      {:telemetry, "~> 1.1"},

      # Used by built-in strategies
      {:murmur, "~> 1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "generator/lib"]
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

  defp description do
    """
    A domain specific language for building scalable, distributed stream processing applications
    with custom distribution strategies.
    """
  end

  defp package do
    [
      licenses: ["MPL-2.0"],
      links: %{github: @github_url, homepage: @home_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      assets: "assets",
      authors: ["Mathijs Saey"],
      source_ref: "develop",
      logo: "assets/logo-light_docs.png",
      formatters: ["html"],
      api_reference: false,
      filter_modules:
        if System.get_env("EX_DOC_PRIVATE") do
          fn _, _ -> true end
        else
          private = ~w(
            Skitter.Config
            Skitter.Telemetry
            Skitter.Runtime.
            Skitter.Remote.
            Skitter.Mode.
        )
          fn mod, _ -> not String.contains?(to_string(mod), private) end
        end,
      extras: [
        {:"README.md", [title: "Skitter", filename: "readme"]},
        "pages/deployment.md",
        "pages/configuration.md",
        "pages/telemetry.md"
      ],
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
          Skitter.Remote,
          Skitter.Runtime
        ],
        dsl: ~r/Skitter.DSL*/,
        "Built-in Components": ~r/Skitter.BIC.*/,
        "Built-in Strategies": ~r/Skitter.BIS.*/,
        utilities: [
          Skitter.Dot,
          Skitter.Config,
          Skitter.Telemetry,
          Skitter.Release,
          Skitter.ExitCodes
        ],
        "Runtime System (private)": ~r/Skitter.Runtime\..*/,
        "Remote Runtimes (private)": ~r/Skitter.Remote\..*/,
        "Runtime Modes (private)": ~r/Skitter.Mode\..*/
      ]
    ]
  end
end
