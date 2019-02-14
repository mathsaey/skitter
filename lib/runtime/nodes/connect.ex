# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Connect do
  @moduledoc false

  require Logger
  alias Skitter.Runtime.Worker

  @doc """
  Connect to a skitter worker node.

  When successful, this function returns `true`. Otherwise, an error is
  returned. (See the "Errors" section below).

  ## Distribution and local mode

  This function will return `:not_distributed` if the current node is not
  alive (i.e. not distributed). As an exception to this rule, a node can
  connect to itself when the skitter application is running in local mode.
  (See `Skitter.Configuration`).

  ## Errors

  The following errors can be returned from this function.

  - `:not_distributed`: The local node is not distributed, can only be returned
    standalone.
  - `:already_connected`: This node is already connected.
  - `:not_connected`: Connecting to the node failed.
  - `:invalid`: The node to connect to is not a skitter worker node.
  """
  def connect(node = :nonode@nohost) do
    # Allow the local node to act as a worker in local mode
    if Worker.verify_worker(node) && !Node.alive?() do
      Worker.register_master(node)
      {:local, node}
    else
      Logger.error "Connecting to the local node is only allowed in local mode."
      {:invalid, node}
    end
  end

  def connect(node) when is_atom(node) do
    with {:connect, true} <- {:connect, Node.connect(node)},
         {:verify, true} <- {:verify, Worker.verify_worker(node)},
         :ok <- Worker.register_master(node)
    do
      Logger.info("Registered new worker: #{node}")
      {:ok, node}
    else
      {:verify, false} -> {:no_skitter_worker, node}
      {:connect, false} -> {:not_connected, node}
      :ignored -> {:not_distributed, node}
      any -> {{:error, any}, node}
    end
  end
end
