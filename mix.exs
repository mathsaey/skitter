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
      releases: releases(),
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

  # -------- #
  # Releases #
  # -------- #

  defp releases, do: [release(:skitter_master), release(:skitter_worker)]
  defp release(name), do: release(name, [name])

  defp release(name, applications) do
    {name,
     [
       applications: for(app <- applications, do: {app, :permanent}),
       runtime_config_path: "config/#{name}.exs",
       include_executables_for: [:unix],
       steps: steps()
     ]}
  end

  # Release Builds
  # --------------

  defp aliases, do: [build: &build_releases/1]

  defp build_releases(args) do
    # When building all releases, we want a single top level folder with the
    # skitter script and the various releases. The default release path
    # includes the release name, but custom paths do not. Thus, when building
    # a release with a custom path, we want to append the release name when
    # individual releases are built.
    # Other options are passed unchanged.
    {args, path} =
      Enum.reduce(args, {[], false}, fn
        "--path", {lst, _} -> {lst, true}
        val, {lst, true} -> {lst, val}
        val, {lst, cur} -> {[val | lst], cur}
      end)

    args = Enum.reverse(args)

    build_release("skitter_worker", args, path)
    build_release("skitter_master", args, path)
  end

  defp build_release(rel, args, false), do: Mix.Tasks.Release.run([rel | args])

  defp build_release(rel, args, path) do
    path = Path.join(path, rel)
    Mix.Tasks.Release.run([rel, "--path", path | args])
  end

  # Always build releases in production
  defp preferred_env, do: [build: :prod, release: :prod]

  # Ensure cookie and deploy script are created along with release files
  defp steps, do: [&put_cookie/1, :assemble, &copy_deploy_script/1]

  defp copy_deploy_script(rel = %Mix.Release{}) do
    target =
      rel.path
      |> Path.split()
      |> Enum.drop(-1)
      |> Path.join()
      |> Path.join("skitter")

    Mix.Generator.copy_template("rel/skitter.sh.eex", target, [release: rel], force: true)

    File.chmod!(target, 0o744)
    rel
  end

  # Cookie Handling
  # ---------------

  defp cookie_path, do: Path.join(Mix.Project.build_path(), "rel_cookie")

  defp put_cookie(rel = %Mix.Release{}), do: put_in(rel.options[:cookie], cookie_get())

  defp cookie_get do
    case File.read(cookie_path()) do
      {:ok, cookie} -> cookie
      {:error, :enoent} -> cookie_create()
    end
  end

  defp cookie_create do
    cookie = Base.url_encode64(:crypto.strong_rand_bytes(40))
    File.write!(cookie_path(), cookie)
    cookie
  end

  # ------------------ #
  # Tool Configuration #
  # ------------------ #

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
        dsl: ~r/Skitter.DSL.*/,
        runtime: ~r/Skitter.(Runtime|Worker|Master).*/,
        utilities: [
          Skitter.Dot
        ]
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

  defp dialyzer, do: [plt_add_apps: [:mix, :iex, :eex]]
end
