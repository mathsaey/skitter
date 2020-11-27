# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  @moduledoc """
  Start a Skitter master node

  This tasks starts the Skitter application in master mode. It accepts a single option and
  multiple arguments. Note that additional arguments need to be passed to `elixir` or `iex` in
  order to be able to connect to other Skitter nodes.

  If you wish to use this task in production, consider if using the Skitter release is not a
  better option for your use case. If you end up using this task, be sure to run mix in production
  mode.

  ## Options and Arguments

  * `--eval`, `-e`: Evaluate the given code after starting the Skitter master.

  Besides this, all other arguments are interpreted as worker nodes. When the master node starts,
  it will attempt to connect to all the specified nodes. If this fails, the master exits.

  ## Distribution Parameters

  In order to connect with other Skitter nodes, the local node needs to be distributed. This task
  does not handle distrbution, instead, the correct parameters should be passed to `iex` or
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
