# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes do
  @moduledoc false

  require Logger

  alias __MODULE__

  @doc """
  List all nodes.
  """
  def all, do: Nodes.Registry.all()

  @doc """
  Connect to a (list of) skitter worker node(s).

  Returns true if successful. When not successful, an error or a list of errors
  is returned instead.
  """
  defdelegate connect(node), to: Nodes.Registry

  @doc """
  Subscribe to node join events.

  When a node joins the network, the pid that called this function will
  receive `{:node_join, node}`.
  """
  defdelegate subscribe_join, to: Nodes.Notifier

  @doc """
  Subscribe to node leave events.

  When a node leaves the network, the pid that called this function will
  receive `{:node_leave, node, reason}`.
  When the node was disconnected through `Nodes.disconnect`, the provided reason
  will be `:removed`.
  """
  defdelegate subscribe_leave, to: Nodes.Notifier

  @doc """
  Unsubscribe from join events.

  The pid will receive no further notifications when a node joins the network.
  """
  defdelegate unsubscribe_join, to: Nodes.Notifier

  @doc """
  Unsubscribe from leave events.

  The pid will receive no further notifications when a node leaves the network.
  """
  defdelegate unsubscribe_leave, to: Nodes.Notifier

  @doc """
  Execute `{mod, func, args}` on `node`, block until a result is available.
  """
  defdelegate on(node, mod, func, args), to: Nodes.Task

  @doc """
  Execute `{mod, func, args}` on every node, obtain the results in a list.
  """
  defdelegate on_all(mod, func, args), to: Nodes.Task

  defdelegate on_permanent(mod, func, args), to: Nodes.Task
  defdelegate on_transient(mod, func, args), to: Nodes.Task

  defdelegate select_permanent(), to: Nodes.LoadBalancer
  defdelegate select_transient(), to: Nodes.LoadBalancer

end
