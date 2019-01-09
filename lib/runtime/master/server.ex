# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.Server do
  @moduledoc false
  use GenServer

  alias Skitter.Runtime.Nodes

  def start_link(nodes) do
    GenServer.start_link(__MODULE__, nodes, name: __MODULE__)
  end

  def init(nodes) do
    case Nodes.connect(nodes) do
      true -> {:ok, nil}
      :not_distributed -> {:stop, :not_distributed}
      lst -> {:stop, {:invalid_nodes, lst}}
    end
  end

  def handle_call({:add_node, node}, _, nil) do
    case Nodes.connect(node) do
      true -> {:reply, true, nil}
      any -> {:reply, {:error, any}, nil}
    end
  end
end
