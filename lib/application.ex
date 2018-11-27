# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false
  use Application

  alias Skitter.Runtime.Worker
  alias Skitter.Runtime.Master

  def start(type, []) do
    start(type, Application.get_env(:skitter, :mode, :master))
  end

  def start(_type, :worker) do
    children = [
      Worker,
      Worker.DynamicWorkflowSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  def start(_type, :master) do
    banner_if_iex()
    nodes = Application.get_env(:skitter, :worker_nodes, [])

    children = [
      {Master.NodeMonitorSupervisor, []},
      {Master, nodes}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp banner_if_iex do
    if Code.ensure_loaded(IEx) && IEx.started?() do
      IO.puts(banner())
    end
  end

  defp banner do
    logo =
      if IO.ANSI.enabled?() do
        "#{IO.ANSI.italic()}⬡⬢⬡⬢ Skitter#{IO.ANSI.reset()}"
      else
        "Skitter"
      end

    "#{logo} (#{Application.spec(:skitter, :vsn)})"
  end
end
