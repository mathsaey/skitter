# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  use Mix.Task

  @moduledoc """
  Start a Skitter master node for the current project.

  A list of worker nodes can be provided as an argument to this command.
  These nodes should have already been started (using `skitter.worker`).

  This task ensures that the started node is distributed. When no name is
  specified, `master` is used.
  Furthermore, using this task implicitly passes the `--no-halt` option to mix.

  If you wish to pass any arguments to the underlying elixir runtime, this task
  can be started as follows: `elixir --arg1 --arg2 -S skitter.master`
  """

  @shortdoc "Start a Skitter master node for the current project."
  def run(args) do
    read_nodes(args)
    Mix.Tasks.Skitter.Boot.boot(:master)
  end

  def read_nodes(args) do
    nodes = Enum.map(args, &String.to_atom/1)
    Application.put_env(:skitter, :worker_nodes, nodes, persistent: true)
  end
end
