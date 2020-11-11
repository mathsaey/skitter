defmodule Skitter.Worker do
  @moduledoc """
  Skitter worker.
  """

  alias __MODULE__

  @doc """
  Connect to the master at `remote`.

  Returns `:ok` if the connection succeeds. See `Skitter.Remote.connect/2` for information about
  the possible errors this may return. Besides the errors listed there, the following custom
  errors may be returned:

  - `{:error, :already_connected}`: The current worker is already connected to the master
  - `{:error, :has_master}`: The current worker already has a master
  """
  @spec connect_master(node()) :: :ok | {:error, atom()}
  def connect_master(remote), do: Worker.MasterConnection.connect(remote)
end
