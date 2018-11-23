# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  use GenServer

  # --- #
  # API #
  # --- #

  def start_link(nodes) do
    GenServer.start_link(__MODULE__, nodes, name: __MODULE__)
  end

  # ------ #
  # Server #
  # ------ #

  def init(nodes) do
    rejected = connect(nodes)

    case rejected do
      [] -> {:ok, nodes}
      :not_distributed -> {:stop, :not_distributed}
      lst -> {:stop, {:invalid_nodes, lst}}
    end
  end

  # Nodes
  # -----

  defp connect(nodes) when is_list(nodes) do
    if Node.alive?() do
      nodes
      |> Enum.map(&connect/1)
      |> Enum.reject(&(&1 == true))
    else
      :not_distributed
    end
  end

  defp connect(node) when is_atom(node) do
    with true <- Node.connect(node),
         true <- Skitter.Runtime.Worker.verify_node(node),
         {:ok, _p} <- Skitter.Runtime.NodeMonitorSupervisor.start_monitor(node) do
      true
    else
      :not_connected -> {:not_connected, node}
      :invalid -> {:no_skitter_worker, node}
      false -> {:not_connected, node}
      any -> {:error, any, node}
    end
  end
end
