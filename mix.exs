# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  def project do
    [
      name: "Skitter",
      version: File.read!("#{__DIR__}/VERSION.txt") |> String.trim(),
      source_url: "https://github.com/mathsaey/skitter/",
      homepage_url: "https://soft.vub.ac.be/~mathsaey/skitter/",
      apps_path: "apps",
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      preferred_cli_env: preferred_env()
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  # ------- #
  # Aliases #
  # ------- #

  defp preferred_env, do: [build: :prod]

  defp aliases do
    [
      build: ["compile", &build/1],
      run: ["compile", &run/1],
      tset: [&test/1]
    ]
  end

  defp run(_) do
    Mix.shell().error("""
      No applications are started when running Skitter from the umbrella root.
      To experiment with Skitter, either build the release (`mix build`), or
      navigate to the individual applications (such as master or worker) in
      the `apps` directory and start an individual application from there.
    """)
  end

  defp test(args) do
    Mix.Project.apps_paths()
    |> Enum.map(fn {app, path} ->
      Mix.Project.in_project(app, path, fn _ ->
        Mix.Tasks.Compile.run()
        Mix.Tasks.Test.run(args)
      end)
    end)
  end

  # Release Builds
  # --------------

  # Build all releases in the umbrella

  defp build(args) do
    path = build_path(args)

    Enum.each(releases(), fn app ->
      path = Path.join(path, Atom.to_string(app))
      build_release(app, args ++ ["--path", path])
    end)

    copy_deploy_script(path)
  end

  defp build_path(args) do
    if idx = Enum.find_index(args, &(&1 == "--path")) do
      Enum.at(args, idx + 1) |> Path.expand()
    else
      Path.join(Mix.Project.build_path(), "rel")
    end
  end

  defp releases do
    Mix.Project.apps_paths()
    |> Enum.map(fn {app, path} -> Mix.Project.in_project(app, path, & &1.project()[:releases]) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn [{rel, _}] -> rel end)
  end

  defp build_release(app, args) do
    Mix.Project.in_project(app, "apps/#{app}", fn _ -> Mix.Tasks.Release.run(args) end)
  end

  defp copy_deploy_script(path) do
    path = Path.join(path, "skitter")
    version = __MODULE__.project()[:version]

    Mix.Generator.copy_template("rel/skitter.sh.eex", path, [version: version], force: true)

    File.chmod!(path, 0o744)
  end

  # ------------------ #
  # Tool Configuration #
  # ------------------ #

  # ExDoc
  # -----

  defp docs do
    [
      main: "readme",
      source_ref: "develop",
      logo: "assets/logo-light_docs.png",
      extras: doc_extras(),
      groups_for_modules: [
        core: [
          Skitter.Element,
          Skitter.Port,
          Skitter.Instance,
          Skitter.Callback,
          Skitter.Callback.Result,
          Skitter.Component,
          Skitter.Workflow,
          Skitter.Strategy,
          Skitter.StrategyError
        ],
        utilities: [
          Skitter.Dot
        ],
        dsl: ~r/Skitter.DSL*/,
        runtime: ~r/Skitter.Runtime*/,
        remote: ~r/Skitter.Remote*/,
        applications: ~r/Skitter.(Worker|Master).*/
      ],
      groups_for_functions: [
        Hooks: &(&1[:section] == :hook)
      ]
    ]
  end

  defp doc_extras do
    "pages/*.md"
    |> Path.wildcard()
    |> Enum.concat(["README.md"])
  end

  # Dialyzer
  # --------

  defp dialyzer, do: [plt_add_apps: [:mix, :iex, :eex]]
end
