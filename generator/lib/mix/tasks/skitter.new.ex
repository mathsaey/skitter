# Copyright 2018 - 2023, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.New do
  @moduledoc """
  Create a Skitter project. It expects the path of the project as an argument.

      $ mix skitter.new PATH [--module MODULE] [--no-fetch-deps] [--fetch-deps] [--develop]

  This task creates a new Skitter project, similar to `mix new` and `mix phx.new`. The project is
  created at PATH and is set up to allow the use of Skitter.

  Specifically, the generated project will contain the following files:

  * a `mix.exs` file which declares Skitter as a dependency and which is set up to build a
    Skitter release.

  * a `config/config.exs` file which provides some initial configuration for Skitter and the
    logger.

  * a `.formatter.exs` file which sets up `mix format`

  * a `lib/MODULE.ex` file which contain an empty workflow to get started.

  * a `README.md` file which documents the project layout.

  * a `.gitignore` file.

  After setting up the project file, this task will fetch the project dependencies if required.

  ## Flags and arguments

  * `--develop`: use the latest development version of Skitter (from github) instead of the
    current stable version (from hex.pm).

  * `--module MODULE`: specify the name of the generated module. If this is not provided, a name
    is generated based on PATH.

  * `--(no-)deps`: By default, the installer asks the user if it should run `mix deps.get` and
  `mix deps.compile` after creating the project. Set this flag to skip this prompt and to
  explicitly opt in or out of automatically running these commands.
  """
  @shortdoc "Create a new Skitter project"
  use Mix.Task
  import Mix.Generator

  @elixir_version Mix.Project.get!().project()[:elixir]
  @skitter_version Mix.Project.get!().project()[:version]

  @impl Mix.Task
  def run(args) do
    flags = [deps: :boolean, develop: :boolean, module: :string]
    {opts, path} = case OptionParser.parse!(args, strict: flags) do
      {_, []} -> Mix.raise("You must specify a path!")
      {_ , ["skitter"]} -> Mix.raise(~s("skitter" is not a valid path name))
      {opts, [name]} -> {opts, name}
    end

    app_name = Path.basename(path)
    module_name = opts[:module] || Macro.camelize(path)

    module_path = module_name |> String.split(".") |> Enum.map(&Macro.underscore/1) |> Path.join()
    module_path = Path.join("lib", "#{module_path}.ex")

    version_check!()
    directory_check!(path)

    create_dirs!(path, Path.dirname(module_path))
    create_files!(path, app_name, module_name, module_path, skitter_version(opts[:develop]))
    maybe_deps(path, opts[:deps])

    Mix.shell().info("""

      Your skitter project has been created at `#{path}`.
      You can now start working on your Skitter application:

      $ cd #{path}
      $ iex -S mix

      For your convenience, the generated README.md file contains a
      summary of the generated files and a summary of elixir commands.
    """)
  end

  defp version_check! do
    unless Version.match?(System.version(), @elixir_version) do
      Mix.raise("Skitter requires Elixir version #{@elixir_version} or higher.")
    end
  end

  defp directory_check!(path) do
    if File.exists?(path) do
      Mix.raise(~s(Directory "#{path}" already exists.))
    end
  end

  defp create_dirs!(path, module_path) do
    create_directory(path)
    create_directory(Path.join(path, module_path))
    create_directory(Path.join(path, "config"))
  end

  defp create_files!(path, app_name, module_name, module_path, version) do
    assigns = [
      app_name: app_name,
      module_name: module_name, module_path: module_path,
      elixir_version: @elixir_version,
      skitter_version: version
    ]

    create_file(Path.join(path, "mix.exs"), mix_template(assigns))
    create_file(Path.join(path, ".formatter.exs"), formatter_text())
    create_file(Path.join(path, "config/config.exs"), config_template(assigns))
    create_file(Path.join(path, module_path), module_template(assigns))
    create_file(Path.join(path, ".gitignore"), gitignore_text())
    create_file(Path.join(path, "README.md"), readme_template(assigns))
  end

  defp skitter_version(true), do: ~s({:skitter, github: "mathsaey/skitter"})
  defp skitter_version(_) do
    version = Version.parse!(@skitter_version)
    ~s({:skitter, "~> #{version.major}.#{version.minor}"})
  end

  defp maybe_deps(path, true), do: do_deps(path)
  defp maybe_deps(_, false), do: nil

  defp maybe_deps(path, nil) do
    maybe_deps(path, Mix.shell().yes?("Fetch and build dependencies?"))
  end

  defp do_deps(path) do
    run_cmd(path, "mix deps.get")
    run_cmd(path, "mix deps.compile")
  end

  defp run_cmd(dir, cmd) do
    Mix.shell().info([:green, "* Running", :reset, " `", cmd, "` in ", dir])
    Mix.shell().cmd("cd #{dir} ; #{cmd}")
  end

  embed_text(:formatter, """
  # This file is used by `mix format`.
  # We include the skitter project as a dependency here to prevent the formatter from adding
  # parentheses to the macros defined by the Skitter DSLs
  [
    inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
    import_deps: [:skitter]
  ]
  """)

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

  embed_template(:config, """
  # This file is used by mix to configure your application before it is compiled.
  # See https://hexdocs.pm/elixir/Config.html for more information.

  import Config

  config :skitter,
    # Set up Skitter to start the workflow defined in `lib/<%= @app_name %>.ex`
    # If you remove this you need to manually call `Skitter.Runtime.deploy/1` to deploy a workflow.
    # You can also pass the `--deploy` option to the skitter deploy script when using releases.
    deploy: &<%= @module_name %>.workflow/0

  # Set up the console logger. Values for level, format and metadata set here will also be used by
  # the file logger. See https://hexdocs.pm/logger/Logger.html.
  config :logger, :console,
    format: "[$time][$level]$metadata $message\\n",
    device: :standard_error

  # Remove all log messages with a priority lower than info at compile time if we are creating a
  # production build.
  if Mix.env() == :prod do
     config :logger, compile_time_purge_matching: [[level_lower_than: :info]]
  end
  """)

  embed_template(:mix, """
  # This file configures how your project is build: it instructs mix (the elixir build tool) on
  # where to find the project dependencies and on how to build a self-contained "release" of this
  # application, which is used to deploy it over a cluster.

  defmodule <%= Macro.camelize(@app_name) %>.MixProject do
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

    # Specifies the dependencies of the application. (https://hexdocs.pm/mix/Mix.Tasks.Deps.html)
    # Skitter must be included here, but you are free to add additional dependencies as needed.
    defp deps do
      [
        <%= @skitter_version %>,
      ]
    end

    # Specifies which releases to build.
    #
    # A release is a self contained artefact which can be deployed over a cluster using the
    # included skitter deploy script (https://hexdocs.pm/mix/Mix.Tasks.Release.html).
    #
    # Skitter tweaks the release process: it provides configuration options for the erlang vm and
    # adds the skitter deploy script. Both of these steps are performed by `Skitter.Release.step/1`.
    # Therefore, each release specified here _must_ contain the following configuration:
    #   [steps: [&Skitter.Release.step/1, :assemble]]
    # Please refer to the `Skitter.Release` documentation for more information.
    #
    # You can specify multiple releases to build multiple data processing pipelines from a single
    # project here.
    defp releases do
      [
        <%= @app_name %>: [steps: [&Skitter.Release.step/1, :assemble]]
      ]
    end

    # Mix alias (https://hexdocs.pm/mix/Mix.html#module-aliases) for building a release.
    # We suppress the output of `mix release` to avoid confusion, as it conflicts with the use of
    # the skitter deploy script.
    #
    # You should remove this alias when building multiple releases for this project, as each release
    # will be written to the same destination folder, overwriting other releases.
    defp aliases, do: [release: "release --quiet --path _release"]

    # Always build releases in production mode
    defp preferred_env, do: [release: :prod]
  end
  """)

  embed_template(:readme, """
  # <%= @app_name %>

  Skitter application generated by `skitter.new`.

  ## Project Structure

  `skitter.new` set up a basic elixir project, which includes Skitter as a
  dependency. The following files and directories define your elixir application:

  File / Directory | Purpose
  ---------------- | -------
  `mix.exs` | Configures how `mix`, the elixir build tool, runs and compiles your application.
  `config/config.exs` | Configures your application and its dependencies (e.g. skitter, logger).
  `lib/*.ex` | Files in this directory define your application and are compiled by mix.
  `_build` | Contains compilation artefacts, can safely be deleted
  `_release` | Contains the release created when running `mix release`, can safely be deleted.

  Application code should be stored in the `lib` directory. `skitter.new` defined
  some code in `<%= @module_path %>` to help you get started.

  ## Executing the Project

  There are several ways to execute elixir code. First and foremost, you can use
  `iex -S mix` to start an elixir REPL (called iex). When iex is started like this,
  it automatically loads your application modules and the Skitter runtime system.
  The Skitter runtime system is started in "local" mode: it acts as both a master
  and worker runtime simultaneously.

  If you want to start a master or worker runtime on your local machine, you can
  use `iex -S mix skitter.worker` or `iex -S mix skitter.master` to do so. This is
  useful to simulate a cluster environment in development. Note that elixir
  applications need to be "named" to communicate with each other. Thus, to start
  a worker and a master node on your local machine, you would need to run
  `iex --sname worker -S mix skitter.worker` in one shell and
  `iex --sname master -S mix skitter.master worker@<hostname>` in the other.
  Please refer to `mix help skitter.master` and `mix help skitter.worker` for more
  information.

  The final method to start a skitter runtime is used to deploy a complete skitter
  system over a cluster. This method uses so-called "releases"
  (https://hexdocs.pm/mix/master/Mix.Tasks.Release.html).
  To use this method, build a release by running `mix release`. By default, this
  release will be stored inside the `_release` directory. This release can be
  deployed over a cluster by using the `_release/bin/skitter deploy` script.

  The complete guide to deploying a Skitter application over a cluster can be
  found at https://hexdocs.pm/skitter/deployment.html.
  """)

  embed_template(:module, """
  # The lib directory contains the various modules which define your application.
  # Any module (and thus any operation or strategy) defined in this directory is compiled by mix and
  # included when you assemble a release.
  #
  # In this file, we provide an example workflow to help you get started with Skitter.
  # config/config.exs contains configuration to automatically deploy this workflow when a Skitter
  # runtime is started.

  defmodule <%= @module_name %> do
    use Skitter.DSL

    def workflow do
      workflow do
        stream_source(~w(Hello Skitter Hello World!))
        ~> flat_map(&String.split/1)
        ~> keyed_reduce(fn word -> word end, fn word, ctr -> {ctr + 1, {word, ctr + 1}} end, 0)
        ~> print()
      end
    end
  end
  """)
end
