# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master do
  @moduledoc false

  use GenServer

  require Logger

  alias Skitter.Runtime.Worker
  alias Skitter.Runtime.Master

  # --- #
  # API #
  # --- #

  def add_node(node) do
    GenServer.call(__MODULE__, {:add_node, node}, :infinity)
  end

  def remove_node(node) do
    GenServer.cast(__MODULE__, {:remove_node, node})
  end

  # ------ #
  # Server #
  # ------ #

  def start_link(nodes) do
    GenServer.start_link(__MODULE__, nodes, name: __MODULE__)
  end

  def init(nodes) do
    conn = connect(nodes)

    case conn do
      true -> {:ok, nil}
      :not_distributed -> {:stop, :not_distributed}
      lst -> {:stop, {:invalid_nodes, lst}}
    end
  end

  # Nodes
  # -----

  def handle_call({:add_node, node}, _from, nil) do
    case connect(node) do
      true -> {:reply, true, nil}
      any -> {:reply, any, nil}
    end
  end

  def handle_cast({:remove_node, node}, nil) do
    Master.Nodes.remove(node)
    {:noreply, nil}
  end

  defp connect(node), do: Master.Nodes.add(node)
end

