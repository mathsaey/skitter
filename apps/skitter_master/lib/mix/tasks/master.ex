# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  @moduledoc """
  Start a Skitter worker node for the current project.

  This task optionally accepts a single argument, which is the name of a skitter
  master node. After the worker is started, it will attempt to connect to this
  node. If connecting to this node fails for some reason, the worker application
  will exit. When no master node is specified, the worker will start and wait
  for a master to connect.

  Note that, unlike the skitter_worker release, this task does not enable
  distribution. To do so, pass the `--sname` or `--name` option to elixir.
  """
  @shortdoc "Start a Skitter worker node for the current project."
  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(args) do
    read_master(args)
    Mix.Tasks.Run.run(args_no_halt())
  end

  defp read_master([]), do: nil
  defp read_master([m]), do: Application.put_env(:skitter_worker, :master, m)

  defp args_no_halt, do: if(IEx.started?(), do: [], else: ["--no-halt"])
end

# TODO: Remove this and just parse opts right in application start?
