defmodule Skitter.Worker do
  @moduledoc """
  Skitter worker.
  """

  alias __MODULE__

  @doc """
  Connect to the master at `remote`.

  Returns `:ok` if the connection succeeds. An `{:error, reason}` tuple is returned otherwise.
  Reason may be any of the following:

  - `:not_distributed`: the local node is not alive according to `Node.alive?/0`
  - `:not_connected`: it was not possible to connect to the remote node
  - `:not_skitter`: the remote node is not a Skitter remote
  - `:incompatible`: the remote node is running an incompatible version of Skitter
  - `:mode_mismatch`: the remote runtime is not a master node
  - `:unknown_mode`: the remote node cannot connect to worker nodes (it may be misconfigured)
  - `:already_connected`: the remote node is already connected to this node
  """
  @spec connect_master(node()) :: :ok | {:error, atom()}
  def connect_master(remote), do: Worker.MasterConnection.connect(remote)
end
