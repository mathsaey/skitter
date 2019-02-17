# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Worker do
  @moduledoc """
  Start a Skitter worker node for the current project.

  This task accepts a single argument, which is the name of the master node.
  After starting the application, the skitter will automatically attempt to
  connect to this master node. If the master node does not exist or is not
  alive, the worker will still start without error. This mechanism is intended
  to be used to reconnect to a master node after failure. Note that the master
  will not use this node as a skitter worker if automatic_connect is set to
  false.

  If you wish to pass any arguments to the underlying elixir runtime, this task
  can be started as follows: `elixir --arg1 --arg2 -S mix skitter.worker`
  """
  @shortdoc "Start a Skitter worker node for the current project."
  use Mix.Task
  import Skitter.Configuration

  @doc false
  def run(args) do
    read_master(args)
    Mix.Tasks.Skitter.Boot.boot(:worker)
  end

  defp read_master([]), do: nil

  defp read_master([arg]) do
    put_env(:master_node, String.to_atom(arg))
  end
end
