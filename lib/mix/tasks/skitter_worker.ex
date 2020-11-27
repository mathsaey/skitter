# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Worker do
  @moduledoc """
  Start a Skitter worker node

  This task starts the Skitter application in worker mode. It accepts a single option and a single
  argument. Note that some additional arguments need to be passed to `elixir` / `iex` in order to
  connect to other Skitter nodes.

  If you wish to use this task in production, consider if using the Skitter release is not a
  better option for your use case. If you end up using this task, be sure to run mix in production
  mode.

  ## Flags and Arguments

  * `--no-shutdown-with-master`: By default, a worker node shuts itself down when its connected
  master node disconnects. This option can be passed to override this behaviour.

  Besides this, the name of a master node can be passed as an argument. On startup, the created
  worker will attempt to connect to the master. If this is not successful, a warning is logged but
  the worker does not shut down.

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
    {options, master, _} = OptionParser.parse(args, strict: [shutdown_with_master: :boolean])

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
