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

  After creating the project files, this task will fetch the project dependencies, installing hex
  if needed.
  """
  @shortdoc "Create a new Skitter project"
  use Mix.Task
  import Mix.Generator

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
    create_files!(base_path, app_name, module_name)
    prepare_environment!(base_path)

    Mix.shell().info("""

      Your skitter project has been created at `#{base_path}`.
      You can now start working on your Skitter application.

      For your convenience, the generated README.md file contains a
      summary of the generated files and a summary of elixir commands.
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
    create_directory(base_path)
    create_directory("#{base_path}/lib")
    create_directory("#{base_path}/config")
  end

  defp create_files!(base_path, app_name, module_name) do
    assigns = [app_name: app_name, module_name: module_name, elixir_version: @elixir_version]

    create_file("#{base_path}/mix.exs", mix_template(assigns))
    create_file("#{base_path}/config/config.exs", config_text())
    create_file("#{base_path}/lib/#{app_name}.ex", module_template(assigns))
    create_file("#{base_path}/.gitignore", gitignore_text())
    create_file("#{base_path}/README.md", readme_template(assigns))
  end

  defp prepare_environment!(base_path) do
    if Mix.shell().yes?("Fetch and build dependencies?") do
      run_cmd(base_path, "mix deps.get")
      run_cmd(base_path, "mix deps.compile")
    end
  end

  defp run_cmd(dir, cmd) do
    Mix.shell().info([:green, "* Running", :reset, " `", cmd, "` in ", dir])
    Mix.shell().cmd("cd #{dir} ; #{cmd}")
  end

  embed_text(:gitignore, """
  # The directory Mix will write compiled artifacts to.
  /_build/

  # The directory the mix release alias writes releases to.
  /_release/

  # If you run "mix test --cover", coverage assets end up here.
  /cover/

  # The directory Mix downloads your dependencies sources to.
  /deps/

  # Where 3rd-party dependencies like ExDoc output generated docs.
  /doc/

  # If the VM crashes, it generates a dump, let's ignore it too.
  erl_crash.dump
  """)

  embed_text(:config, """
  # This file is used by mix to configure your application before it is compiled.
  # See: https://hexdocs.pm/elixir/Config.html for more information.
  #
  # Here, we only configure the logger.
  # You are free to delete or modify this file.

  import Config

  # Set up the console logger. Values for level, format and metadata set here will also be used by
  # the file logger.
  config :logger, :console,
    format: "[$time][$level$levelpad]$metadata $message\n",
    device: :standard_error

  # Remove all log messages with a priority lower than info at compile time if we are creating a
  # production build.
  case Mix.env() do
    :prod -> config :logger, compile_time_purge_matching: [[level_lower_than: :info]]
    _ -> nil
  end
  """)

  embed_template(:mix, """
  # Mix is the elixir build tool.
  #
  # This file configures how your project is build: it instructs mix on where to find the project
  # dependencies and on how to build a self-contained "release" of this application.

  defmodule <%= @module_name %>.MixProject do
    use Mix.Project

    def project do
      [
        app: :<%= @app_name %>,
        version: "0.1.0",
        elixir: "<%= @elixir_version %>",
        start_permanent: Mix.env() == :prod,
        preferred_cli_env: preferred_env(),
        releases: releases(),
        aliases: aliases(),
        deps: deps(),
      ]
    end

    # Always build releases in production mode
    defp preferred_env, do: [release: :prod]

    # Mix alias (https://hexdocs.pm/mix/Mix.html#module-aliases) for building a release.
    # We suppress the output of `mix release` to avoid confusion, as it conflicts with the use of
    # the skitter deploy script.
    defp aliases, do: [release: "release --quiet --path _release"]

    # Specifies which releases to build. (https://hexdocs.pm/mix/Mix.Tasks.Release.html)
    # A release is a self contained artefact which can be deployed over a cluster using the
    # included skitter deploy script.
    # You can specify multiple releases to build multiple data processing pipelines from a single
    # project here.
    # Skitter tweaks the release process: it configures the erlang vm and adds the skitter deploy
    # script. Therefore, each release specified here must contain the following configuration:
    #   [steps: [&Skitter.Release.step/1, :assemble]]
    #
    defp releases do
      [
        <%= @app_name %>: [steps: [&Skitter.Release.step/1, :assemble]]
      ]
    end

    # Specifies the dependencies of the application. (https://hexdocs.pm/mix/Mix.Tasks.Deps.html)
    # Skitter must be included here, but you are free to add additional dependencies as needed.
    defp deps do
      [
        {:skitter, github: "mathsaey/skitter"},
      ]
    end
  end
  """)

  embed_template(:readme, """
  # <%= @app_name %>

  Skitter application generated by `skitter.new`.

  ## Project Structure

  `skitter.new` set up a basic elixir project, which includes Skitter as a dependency. The
  following files and directories define your elixir application:

  File / Directory | Purpose
  ---------------- | -------
  `mix.exs` | Configures how `mix`, the elixir build tool, runs and compiles your application.
  `config/config.exs` | Configures your application and its dependencies (e.g. skitter, logger).
  `lib/*.ex` | Files in this directory define your application and are compiled by mix.
  `_build` | Contains compilation artefacts, can safely be deleted
  `_release` | Contains the release created when running `mix release`

  Application code should be stored in the `lib` directory. `skitter.new` defined some example
  code in `lib/<%= @app_name %>` to help you get started.

  ## Executing the Project

  There are several ways to execute elixir code. First and foremost, you can use `iex -S mix` to
  start an elixir REPL (called iex). When iex is started like this, it automatically loads your
  application modules and the Skitter runtime system. The Skitter runtime system is started in
  "local" mode: it acts as both a master and a worker runtime simultaneously.

  If you want to start a master or worker runtime on your local machine, you can use
  `iex -S mix skitter.worker` or `iex -S mix skitter.master` to do so. This is useful to simulate
  a cluster environment in development. Note that some extra steps are required to allow masters
  and workers spawned like this to interact with one another, please use `mix help skitter.worker`
  and `mix help skitter.master` for more information.

  The final method to start a skitter runtime is used to deploy a complete skitter system over a
  cluster. This method uses so-called "releases" (https://hexdocs.pm/mix/master/Mix.Tasks.Release.html).
  To use this method, build a release by running `mix release`. By default, this release will be
  stored inside the `_release` directory. This release can be deployed over a cluster by using the
  `_release/bin/skitter` script. Please use `./_release/bin/skitter help` for more information.
  """)

  embed_template(:module, """
  # The lib directory contains the various modules which define your application.
  # Any module (and thus any component or strategy) defined in this directory is compiled by mix and
  # included when you assemble a release.
  # In this file, we provide an example workflow to help you get started with Skitter.
  # Happy hacking!

  defmodule <%= @module_name %> do
    use Skitter.DSL

    def workflow do
      workflow do
      end
    end
  end
  """)
end
