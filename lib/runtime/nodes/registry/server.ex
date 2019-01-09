# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Registry.Server do
  @moduledoc false

  use GenServer
  alias Skitter.Runtime.Nodes

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Nodes.Notifier.subscribe_join()
    Nodes.Notifier.subscribe_leave()
    {:ok, MapSet.new()}
  end

  def handle_info({:node_join, node}, set) do
    {:noreply, MapSet.put(set, node)}
  end

  def handle_info({:node_leave, node, _}, set) do
    {:noreply, MapSet.delete(set, node)}
  end

  def handle_call(:all, _, set) do
    {:reply, MapSet.to_list(set), set}
  end
end
