# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule SkitterNew.MixProject do
  use Mix.Project

  @github_url "https://github.com/mathsaey/skitter/"
  @home_url "https://soft.vub.ac.be/~mathsaey/skitter/"

  def project do
    [
      app: :skitter_new,
      elixir: "~> 1.13",
      version: "0.6.0-dev",
      source_url: @github_url,
      homepage_url: @home_url,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
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

  defp package do
    [
      licenses:  ["MPL-2.0"],
      links: %{
        github: @github_url,
        homepage: @home_url
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
    ]
  end
end
