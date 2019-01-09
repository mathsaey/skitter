# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Notifier do
  @moduledoc false
  @topics [:add, :remove, :node_down]

  alias __MODULE__.Server

  def subscribe_join do
    GenServer.cast(Server, {:subscribe, self(), :node_join})
  end

  def subscribe_leave do
    GenServer.cast(Server, {:subscribe, self(), :node_leave})
  end

  def unsubscribe_join do
    GenServer.cast(Server, {:unsubscribe, self(), :node_join})
  end

  def unsubscribe_leave do
    GenServer.cast(Server, {:unsubscribe, self(), :node_leave})
  end

  def notify_join(node) do
    GenServer.cast(Server, {:node_join, node})
  end

  def notify_leave(node, reason) do
    GenServer.cast(Server, {:node_leave, node, reason})
  end
end
