# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.New do
  @moduledoc """
  Create a Skitter project.

  This task creates a new Skitter project, similar to `mix new` and `mix phx.new`. Concretely, it
  creates a mix project set up to allow the use of Skitter. It expects the name of the project as
  an argument:

      $ mix skitter.new NAME

  The provided NAME will be used as the path for the new project.
  """
  @shortdoc "Create a new Skitter project"
  use Mix.Task
  alias Mix.Generator, as: Gen

  @elixir_version "~> 1.12"

  @impl Mix.Task
  def run(args) do
    {[], [name]} = OptionParser.parse!(args, strict: [])

    if name == "skitter" do
      Mix.raise("You must not use skitter as the name of your application")
    end

    app_name = String.to_atom(name)
    module_name = Macro.camelize(name)
    base_path = name

    version_check!()
    directory_check!(base_path)
    create_dirs!(base_path)
    copy_files!(base_path)
    copy_templates!(base_path, app_name, module_name)

    Mix.shell().info("""

      Your skitter project has been created at #{base_path}.

      Next, you should enter the following commands:

         cd #{base_path}
         mix deps.get
         mix deps.compile

      Afterwards, you can start working on your Skitter application.

      If you are not familiar with Elixir and its build tool, Mix:
        lib/               contains your application code
        mix.exs            configures how your application is built
        config/config.exs  can be used to configure your application

      You can use:
        iex -S mix                to run your skitter application locally
        iex -S mix skitter.master to start a local master runtime
        iex -S mix skitter.worker to start a local worker runtime
        mix release               to build a release to deploy over a cluster.

      Please refer to the Skitter documentation for additional information.
    """)
  end

  defp version_check! do
    unless Version.match?(System.version(), @elixir_version) do
      Mix.raise("Skitter requires Elixir version 1.12 or higher.")
    end
  end

  defp directory_check!(base_path) do
    if File.exists?(base_path) do
      Mix.raise("Directory #{base_path} already exists.")
    end
  end

  defp create_dirs!(base_path) do
    Gen.create_directory(base_path)
    Gen.create_directory("#{base_path}/lib")
    Gen.create_directory("#{base_path}/config")
  end

  defp copy_files!(base_path) do
    Gen.copy_file("#{template_path()}/gitignore", "#{base_path}/.gitignore")
    Gen.copy_file("#{template_path()}/config/config.exs", "#{base_path}/config/config.exs")
  end

  defp copy_templates!(base_path, app_name, module_name) do
    assigns = [app_name: app_name, module_name: module_name, elixir_version: @elixir_version]
    Gen.copy_template("#{template_path()}/mix.exs.eex", "#{base_path}/mix.exs", assigns)
    Gen.copy_template("#{template_path()}/README.md.eex", "#{base_path}/README.md", assigns)

    Gen.copy_template(
      "#{template_path()}/lib/app_name.ex.eex",
      "#{base_path}/lib/#{app_name}.ex",
      assigns
    )
  end

  defp template_path, do: __DIR__ |> Path.join("../../../templates") |> Path.relative_to_cwd()
end
