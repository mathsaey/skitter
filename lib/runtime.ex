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
      lst -> {:stop, {:invalid_nodes, lst}}
    end
  end

  # Nodes
  # -----

  defp connect(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&connect/1)
    |> Enum.zip(nodes)
    |> Enum.map(fn {bool, el} -> if bool, do: bool, else: el end)
    |> Enum.reject(&(&1 == true))
  end

  defp connect(node) when is_atom(node) do
    Node.connect(node) && Skitter.Runtime.Worker.verify_worker(node)
  end
end
