# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Handler do
  @moduledoc false
  alias __MODULE__.Dispatcher

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def init(), do: nil

      defoverridable init: 0
    end
  end

  @doc """
  Ask the local handler for `mode` to accept `remote`.
  """
  @spec accept_local(atom(), node()) :: :ok | {:error, atom()}
  def accept_local(mode, remote), do: Dispatcher.dispatch(mode, {:accept, remote})

  @doc """
  Ask the handler for `mode` on `remote` to accept the current node.
  """
  @spec accept_remote(node(), atom()) :: :ok | {:error, atom()}
  def accept_remote(remote, mode), do: Dispatcher.dispatch(remote, mode, {:accept, Node.self()})

  @doc """
  Ask the local handler for `mode` to remove `remote`.
  """
  @spec remove(atom(), node()) :: :ok
  def remove(mode, remote), do: Dispatcher.dispatch(mode, {:remove, remote})

  defdelegate get_pid(mode), to: Dispatcher, as: :get_handler

  @doc """
  Create an initial state.

  Optional callback which is called when the handler is installed. This is useful to set up an
  initial state if your handler maintains state.
  """
  @callback init() :: any()

  @doc """
  Accept or reject a connection from a `node` with `mode`.

  Return `{:ok, new_state}` to accept the connection, or `{:error, reason, new_state}` to reject.
  """
  @callback accept_connection(node :: node(), mode :: atom(), state :: any()) ::
              {:ok, any()} | {:error, atom(), any()}

  @doc """
  Remove a previously established connection from the state.

  It is possible that the local `ConnectionHandler` accepts a connection that is later rejected by
  the remote runtime. When this happens, this callback is called to clean up `state`.
  """
  @callback remove_connection(node :: node(), state :: any()) :: any()

  @doc """
  Respond to a remote runtime disconnecting.
  """
  @callback remote_down(node :: node(), state :: any()) :: any()
end
