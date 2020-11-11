# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Handler do
  @moduledoc """
  Callback module to create a handler.

  A handler determines how connections from remote Skitter runtimes with a given _mode_ are
  handled. In order to handle a given type, create a module which calls `use
  Skitter.Remote.ConnectionHandler` and implement the callbacks defined in this module. When
  this is done, the `:skitter_remote` application will automatically invoke the callbacks defined
  in this module when appropriate.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def init(), do: nil

      defoverridable init: 0
    end
  end

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
