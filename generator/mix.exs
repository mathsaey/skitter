# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule SkitterNew.MixProject do
  use Mix.Project

  def project do
    skitter_project = Mix.Project.in_project(:skitter, "../", &(&1.project()))
    [
      app: :skitter_new,
      version: skitter_project[:version],
      elixir: skitter_project[:elixir],
      start_permanent: Mix.env() == :prod,
      deps: [],
      description: description(),
      package: package(skitter_project),
      source_url: skitter_project[:source_url],
      homepage_url: skitter_project[:homepage_url]
    ]
  end

  def application do
    [
      extra_applications: [:eex]
    ]
  end

  defp description do
    """
    Skitter project generator.

    Provides a `mix skitter.new` task to set up a Skitter project.
    """
  end

  defp package(skitter_project) do
    [
      licenses:  ["MPL-2.0"],
      links: %{
        github: skitter_project[:source_url],
        homepage: skitter_project[:homepage_url]
      }
    ]
  end
end
