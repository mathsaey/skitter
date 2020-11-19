defmodule Skitter.Master do
  @moduledoc """
  Skitter master,
  """

  @doc """
  Attempt to connect to `workers`.

  Attempt to connect to all the provided worker nodes. When successful, `:ok` is returned. If
  this fails, `{:error, list}` is returned, where `list` is a list of `{worker, reason}` tuples.
  Reason indicates the error that occurred when the server attempted to connect with `worker`.

  The following errors may be present in the list:

  - `:not_distributed`: the local node is not alive according to `Node.alive?/0`
  - `:not_connected`: it was not possible to connect to the remote node
  - `:not_skitter`: the remote node is not a Skitter remote
  - `:incompatible`: the remote node is running an incompatible version of Skitter
  - `:mode_mismatch`: the remote runtime is not a worker node
  - `:unknown_mode`: the remote node cannot connect to master nodes (it may be misconfigured)
  - `:already_connected`: the remote is already connected to this node
  - `:has_master`: the remote is already connected to a different master
  """
  @spec connect_workers(node() | [node()]) :: :ok | {:error, [{node(), any()}]}
  def connect_workers(workers), do: Skitter.Master.WorkerConnection.connect(workers)
end
