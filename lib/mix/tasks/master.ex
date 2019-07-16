# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  @moduledoc """
  Start a Skitter master node for the current project.

  A list of worker nodes can be provided as an argument to this command.
  These nodes should have already been started (using `skitter.worker`).
  Using this task implicitly passes the `--no-halt` option to mix.

  The `--eval` (or `-e`) switch can be used to evaluate an expression, similar
  to `mix run`.

  If you wish to pass any arguments to the underlying elixir runtime, this task
  can be started as follows: `elixir --arg1 --arg2 -S mix skitter.master`
  """
  @shortdoc "Start a Skitter master node for the current project."

  use Mix.Task
  import Skitter.Runtime.Configuration

  @doc false
  def run(args) do
    run_args = parse_args(args)
    Mix.Tasks.Skitter.Boot.boot(:master, run_args)
  end

  defp parse_args(args) do
    {parsed, argv, _} = OptionParser.parse(
      args,
      aliases: [e: :eval],
      strict: [eval: :keep]
    )

    read_nodes(argv)
    OptionParser.to_argv(parsed)
  end

  defp read_nodes(args) do
    nodes = Enum.map(args, &String.to_atom/1)
    put_env(:worker_nodes, nodes)
  end
end
