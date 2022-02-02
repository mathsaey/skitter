# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  @moduledoc """
  Start a Skitter master node

  This task starts a Skitter master node. It accepts a single option (`--eval`) and multiple
  arguments, which represent worker nodes to connect to. In order to connect to the specified
  workers, additional arguments need to be passed to the `elixir` or `iex` command used to start
  the system. More information can be found in the "Distribution Parameters" section below.

  It is not recommended to use this task in production. Consider using the `skitter.release` task
  to build a release instead. If mix is used anyway, be sure to start in production mode.

  ## Options and Arguments

  * `--eval`, `-e`: Evaluate the given code after skitter has started.

  Besides the `--eval` option, any other argument is interpreted as the name of a worker node.
  The master node will attempt to connect to all the specified nodes when it is starting. If this
  fails, the master exits.

  ## Distribution Parameters

  In order to connect with other Skitter nodes, the local node needs to be distributed. This task
  does not handle distribution, instead, the correct parameters should be passed to `iex` or
  `elixir`. A few examples are provided below:

  - `elixir --sname master -S mix skitter.master`
  - `iex --sname master -S mix skitter.master`.
  - `elixir --name master@hostname -S mix skitter.master`
  - `iex --name master@hostname -S mix skitter.master`.
  """
  @shortdoc "Start a Skitter master node"
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {options, workers, _} = OptionParser.parse(args, aliases: [e: :eval], strict: [eval: :keep])

    Mix.Tasks.Skitter.start(
      :master,
      [workers: Enum.map(workers, &String.to_atom/1)],
      OptionParser.to_argv(options)
    )
  end
end
