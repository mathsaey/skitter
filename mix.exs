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
      elixir: "~> 1.16",
      version: "0.7.0-dev",
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

  defp deps do
    [
      # Dev
      {:credo, "~> 1.7", only: :dev, optional: true, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, optional: true, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, optional: true, runtime: false},

      # Runtime
      {:telemetry, "~> 1.2"},

      # Used by built-in strategies
      {:murmur, "~> 1.0"}
    ]
  end

  def application do
    [
      mod: {Skitter.Runtime.Application, []},
      start_phases: [sk_log: [], sk_welcome: [], sk_connect: [], sk_deploy: []],
      extra_applications: [:logger, :eex]
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

  defp manual_pages do
    [
      "Getting Started": ~w(manual/overview.md manual/installation.md manual/up_and_running.md),
      Concepts: ~w(
        manual/concepts.md
        manual/workflows.md
        manual/operations.md
        manual/strategies.md
      ),
      Deployment: ~w(manual/deployment.md manual/configuration.md),
      Guides: ~w(manual/operators.md manual/telemetry.md)
    ]
  end

  defp docs do
    [
      main: "overview",
      assets: "assets",
      formatters: ["html"],
      source_ref: "develop",
      authors: ["Mathijs Saey"],
      logo: "assets/logo-light_docs.png",
      # Manual
      extra_section: "manual",
      extras: Enum.flat_map(manual_pages(), fn {_, pages} -> pages end),
      groups_for_extras: manual_pages(),
      # Module documentation
      api_reference: false,
      # nest_modules_by_prefix: [Skitter.DSL, Skitter.BIO, Skitter.BIS],
      groups_for_modules: [
        "Domain-specific Languages": ~r/Skitter\.DSL\..*/,
        "Language Abstractions": [
          Skitter.Operation,
          Skitter.Workflow,
          Skitter.Strategy,
          Skitter.Token
        ],
        "Strategy Behaviours": ~r/Skitter\.Strategy\..*/,
        "Runtime Interaction": [
          Skitter.Worker,
          Skitter.Deployment,
          Skitter.Remote,
          Skitter.Runtime
        ],
        "Built-in Operations": ~r/Skitter.BIO.*/,
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
      ],
      groups_for_docs: [
        "Managing State (defoperation)": &(&1[:group] == :state and &1[:inside] == :defoperation),
        "Managing State (defcb)": &(&1[:group] == :state and &1[:inside] == :defcb),
        "Publishing Data": &(&1[:group] == :emit),
        "Meta-Information": &(&1[:group] == :token)
      ],
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
        end
    ]
  end
end
