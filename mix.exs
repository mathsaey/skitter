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
      {:credo, "~> 1.4", only: :dev, runtime: false},
      # Temporary use master until issue is in latest release
      # https://github.com/elixir-lang/ex_doc/issues/1173
      {:ex_doc, github: "elixir-lang/ex_doc", only: :dev, runtime: false},
      # {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      source_ref: "develop",
      logo: "assets/logo-light_docs.png",
      extras: Path.wildcard("app/*/pages/*.md"),
      groups_for_modules: [
        core: [
          Skitter.Element,
          Skitter.Port,
          Skitter.Instance,
          Skitter.Callback,
          Skitter.Callback.Result,
          Skitter.Component,
          Skitter.Workflow,
          Skitter.Strategy
        ],
        utils: [Skitter.Dot],
        dsl: ~r/Skitter.DSL.*/,
        runtime: ~r/Skitter.(Runtime|Worker|Master).*/
      ]
    ]
  end

  defp dialyzer, do: [plt_add_apps: [:mix, :iex, :eex]]

  defp preferred_env do
    [
      build: :prod,
      release: :prod
    ]
  end

  defp aliases do
    [
      clean: [
        fn _ -> cookie_clean() end,
        "clean"
      ],
      build: [
        "release skitter_master",
        fn _ -> Mix.Task.reenable("release") end,
        "release skitter_worker"
      ]
    ]
  end

  defp releases do
    [
      release(:skitter_master),
      release(:skitter_worker)
    ]
  end

  defp release(name), do: release(name, [name])

  defp release(name, applications) do
    {name,
     [
       applications: for(app <- applications, do: {app, :permanent}),
       reboot_system_after_config: false,
       include_executables_for: [:unix],
       steps: steps()
     ]}
  end

  defp steps do
    [&put_cookie/1, :assemble]
  end

  defp put_cookie(rel = %Mix.Release{}) do
    put_in(rel.options[:cookie], cookie_get())
  end

  @cookie_path "rel/cookie"

  defp cookie_get do
    case File.read(@cookie_path) do
      {:ok, cookie} -> cookie
      {:error, :enoent} -> cookie_create()
    end
  end

  defp cookie_create do
    cookie = Base.url_encode64(:crypto.strong_rand_bytes(40))
    File.write!(@cookie_path, cookie)
    cookie
  end

  defp cookie_clean do
    File.rm(@cookie_path)
  end
end
