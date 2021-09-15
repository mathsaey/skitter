# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Worker do
  @moduledoc """
  Start a Skitter worker node

  This task starts a Skitter worker node. It accepts a single argument which represents the master
  the worker will try to connect to and several options.  In order to be able to connect to the
  specified master (and other workers), additional arguments need to be passed to the `elixir` or
  `iex` command used to start the system. More information can be found in the "Distribution
  Parameters" section below.

  It is not recommended to use this task in production. Consider using the `skitter.release` task
  to build a release instead. If mix is used anyway, be sure to start in production mode.

  ## Flags and Arguments

  * `--no-shutdown-with-master`: By default, a worker node shuts itself down when its connected
  master node disconnects. This option can be passed to override this behaviour.
  * `--tag` or `-t`: Specify a `t:Skitter.Nodes.tag/0` for this worker node. This option can be
  used multiple times.

  Besides this, the name of a master node can be passed as an argument. The worker will attempt to
  connect to the specified master. If this is not successful, a warning is logged, however, the
  worker will not shut down.

  ## Distribution Parameters

  In order to connect with other Skitter nodes, the local node needs to be distributed. This task
  does not handle distrbution, instead, the correct parameters should be passed to `iex` or
  `elixir`. A few examples are provided below:

  - `elixir --sname worker -S mix skitter.worker`
  - `iex --sname worker -S mix skitter.worker`.
  - `elixir --name worker@hostname -S mix skitter.worker`
  - `iex --name worker@hostname -S mix skitter.worker`.
  """
  @shortdoc "Start a Skitter worker node"
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {options, master, _} =
      OptionParser.parse(args,
        aliases: [t: :tag],
        strict: [shutdown_with_master: :boolean, tag: :keep]
      )

    {tags, options} = Keyword.pop_values(options, :tag)
    options = Keyword.put_new(options, :tags, Enum.map(tags, &String.to_atom/1))

    options =
      case master do
        [master] ->
          [master: String.to_atom(master)] ++ options

        [] ->
          options

        _ ->
          Mix.shell().error("Ignorning incorrect master option")
          []
      end

    Mix.Tasks.Skitter.start(:worker, options, [])
  end
end
