# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.LoadBalancer.Server do
  @moduledoc false

  use GenServer

  alias Skitter.Runtime.Nodes.{Notifier, Registry}

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Notifier.subscribe_join()
    Notifier.subscribe_leave()
    {:ok, []}
  end

  def handle_info({:node_join, node}, lst) do
    {:noreply, [node | lst]}
  end

  def handle_info({:node_leave, node, _}, lst) do
    {:noreply, List.delete(lst, node)}
  end

  def handle_call(:transient, _, [node | rest]) do
    # TODO: use something more efficient (use a ring?)
    {:reply, node, rest ++ [node]}
  end

  def handle_call(:permanent, _, [node | rest]) do
    # TODO: Check status of nodes
    {:reply, node, rest ++ [node]}
  end
end
