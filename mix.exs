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
      elixir: "~> 1.11",
      version: "0.5.0-dev",
      source_url: "https://github.com/mathsaey/skitter/",
      homepage_url: "https://soft.vub.ac.be/~mathsaey/skitter/",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_env(),
      deps: deps(),
      docs: docs(),
      xref: xref(),
      aliases: aliases(),
      releases: releases(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      mod: {Skitter.Runtime.Application, []},
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
      {:logger_file_backend, "~> 0.0.11"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp preferred_env, do: [release: :prod]

  # ------- #
  # Release #
  # ------- #

  defp aliases do
    [
      release: &release/1
    ]
  end

  defp releases do
    [
      skitter_rel: [
        include_executables_for: [:unix],
        runtime_config_path: "config/release.exs",
        steps: [:assemble, &copy_deploy_script/1]
      ]
    ]
  end

  defp copy_deploy_script(rel = %Mix.Release{}) do
    target = rel.path |> Path.split() |> Enum.drop(-1) |> Path.join() |> Path.join("skitter")
    Mix.Generator.copy_template("rel/skitter.sh.eex", target, [release: rel], force: true)
    File.chmod!(target, 0o744)
    rel
  end

  defp release(args) do
    # We want to add the release script in the folder where the release is placed. Thus, if a
    # custom path is given, we add the release name to the path so the actual release will be
    # placed there.
    {args, _} =
      Enum.map_reduce(args, false, fn
        "--path", _ -> {"--path", true}
        el, true -> {Path.join(el, "skitter_rel"), false}
        el, _ -> {el, false}
      end)

    Mix.Tasks.Release.run(args)
  end

  # ----- #
  # Tools #
  # ----- #

  defp dialyzer do
    [plt_add_apps: [:mix, :iex, :eex]]
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
        utilities: [
          Skitter.Dot
        ]
      ]
    ]
  end
end
