# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Connect do
  @moduledoc false

  require Logger
  alias Skitter.Runtime.Nodes.Worker

  @doc """
  Connect to a skitter worker node.

  When successful, this function returns `:ok`. Otherwise, an error pair is
  returned.

  ## Distribution and local mode

  This function will return `{:error, :not_distributed}` if the current node is
  not alive (i.e. not distributed). However, a non-distributed skitter runtime
  in local mode can connect to itself.

  ## Errors

  If the connection did not succeed, an `{:error, reason}` is returned. Any of
  the following reasons can be returned:

  - `:connect_to_self`: Could not connect to self, this generally happens when
  a non local-mode node attempts to connect to itself.
  - `:not_distributed`: The local node is not distributed.
  - `:not_connected`: Connecting to the node failed.
  - `:invalid_node`: The node to connect to is not a skitter worker node.
  """
  def connect(node = :nonode@nohost) do
    # Allow the local node to act as a worker in local mode
    if Worker.verify_worker(node) && !Node.alive?() do
      Worker.register_master(node)
      :ok
    else
      {:error, :connect_to_self}
    end
  end

  def connect(node) when is_atom(node) do
    with {:connect, true} <- {:connect, Node.connect(node)},
         {:verify, true} <- {:verify, Worker.verify_worker(node)},
         :ok <- Worker.register_master(node)
    do
      :ok
    else
      {:verify, false} -> {:error, :invalid_node}
      {:connect, false} -> {:error, :not_connected}
      {:connect, :ignored} -> {:error, :not_distributed}
      any -> {:error, any}
    end
  end

  @doc """
  Disconnect from a worker node.
  """
  def disconnect(node), do: Worker.remove_master(node)
end
