# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  def project do
    [
      app: :skitter,
      name: "Skitter",
      version: "0.2.0-dev",
      source_url: "https://github.com/mathsaey/skitter/",
      homepage_url: "https://soft.vub.ac.be/~mathsaey/skitter/",
      elixir: "~> 1.9",
      deps: deps(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      mod: {Skitter.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Dev tools
      {:credo, "~> 1.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      source_ref: "develop",
      logo: "assets/logo-light_docs.png",
      extras: Path.wildcard("pages/*.md"),
      groups_for_modules: [
        "Language Concepts": [
          Skitter.Port,
          Skitter.Element,
          Skitter.Instance,
          ~r/Skitter\.Component.*/,
          ~r/Skitter\.Workflow.*/
        ],
        Prelude: [
          ~r/Skitter\.Prelude.*/
        ]
      ],
      groups_for_functions: [
        Hooks: &(&1[:section] == :hooks),
        Language: &(&1[:section] == :dsl),
        "Master/local mode": &(&1[:mode] == [:master, :local]),
        "Master mode": &(&1[:mode] == :master),
        "Worker mode": &(&1[:mode] == :worker)
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer, do: [plt_add_apps: [:mix, :iex]]
end
