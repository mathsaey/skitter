defmodule Skitter.Master do
  @moduledoc """
  Skitter master,
  """

  @doc """
  Attempt to connect to `workers`.

  Attempt to connect to all the provided worker runtimes. When successful, `:ok` is returned. If
  this fails, `{:error, list}` is returned, where `list` is a list of `{worker, reason}` tuples.
  Reason indicates the error that occurred when the server attempted to connect with `worker`.

  The various possible errors are documented in `Skitter.Remote.connect/2`
  """
  @spec connect_workers(node() | [node()]) :: :ok | {:error, [{node(), any()}]}
  def connect_workers(workers), do: Skitter.Master.WorkerConnection.connect(workers)
end
