# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This file is used to ensure the various skitter applications and libraries are built in a
# consistent way. Every skitter application should load this module in its `mix.exs` file through
# the use of `Code.require_file("../../setup.exs"). Afterwards, `lib/3` should be used for library
# applications, while `rel/3` should be used for applications which will be built into a release.

defmodule Setup do
  defp default_project_opts(app, config) do
    [
      app: app,
      elixir: "~> 1.11",
      version: File.read!("#{__DIR__}/VERSION.txt") |> String.trim(),
      start_permanent: Mix.env() == :prod,
      lockfile: "#{__DIR__}/mix.lock",
      deps_path: "#{__DIR__}/deps",
      build_path: "#{__DIR__}/_build",
      config_path: config,
      preferred_cli_env: [
        release: :prod
      ]
    ]
  end

  defp project(app, config, extra), do: Keyword.merge(default_project_opts(app, config), extra)

  def lib(app, extra \\ []) do
    project(app, "#{__DIR__}/config/config.exs", extra)
  end

  def rel(app, extra \\ []) do
    project(app, "config/config.exs", extra) ++ [releases: [release(app)]]
  end

  # ------- #
  # Release #
  # ------- #

  defp release(app) do
    {app,
     [
       rel_templates_path: "#{__DIR__}/rel",
       runtime_config_path: "config/release.exs",
       include_executables_for: [:unix],
       validate_compile_env: false,
       steps: [&cookie/1, :assemble]
     ]}
  end

  # Cookie
  # ------

  # When a skitter release is built, a cookie is created and stored inside the build directory.
  # Future releases will look for this cookie and use it if it is present. This ensures the
  # various releases can talk to each other.

  defp cookie(rel = %Mix.Release{}), do: put_in(rel.options[:cookie], cookie_get())

  defp cookie_path, do: Path.join(Mix.Project.build_path(), "rel_cookie")

  defp cookie_get do
    case File.read(cookie_path()) do
      {:ok, cookie} -> cookie
      {:error, :enoent} -> cookie_create()
    end
  end

  defp cookie_create do
    cookie = Base.encode32(:crypto.strong_rand_bytes(32))
    File.write!(cookie_path(), cookie)
    cookie
  end
end
