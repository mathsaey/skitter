# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Callback do
  @moduledoc """
  Representation of a component callback.

  A callback is a piece of code which implements some functionality of a `Skitter.Component`.
  Internally, a callback is defined as an anonymous function and some metadata.

  This module defines the internal representation of a callback and contains some utilities to
  manipulate callbacks.
  """
  alias Skitter.Component

  # Types
  # -----

  defmodule Result do
    @moduledoc """
    Struct returned by a successful component callback. See `t:t/0`.
    """
    alias Skitter.Callback
    alias Skitter.Port

    @typedoc """
    Structure of published data.

    When a callback publishes data it returns the published data as a keyword list. The keys in
    this list represent the names of output ports; the values of the keys represent the data to be
    publish on an output port.
    """
    @type publish :: [{Port.t(), any()}]

    @typedoc """
    Return value of a callback invocation.

    A callback returns:
    - The result of the callback
    - The published data or `nil` if no data has been published.
    - The updated state, or `nil` if the state has not been changed.
    """
    @type t :: %__MODULE__{
            state: Callback.state() | nil,
            publish: publish() | nil,
            result: any()
          }

    defstruct [:state, :publish, :result]
  end

  @typedoc """
  Callback representation.

  A callback is defined as a function with type `t:signature`, which implements the functionality
  of the callback and a set of metadata which define the capabilities of the callback, and store
  its arity.

  The capabilities of a callback specify if callback can read its state, write its state and if it
  can publish data. If no capabilities are stated when creating the callback, it is assumed the
  callback uses all of its capabilities (i.e. `read?`, `write?` and `publish?` are all set to
  `true`).
  """
  @type t :: %__MODULE__{
          function: signature(),
          arity: non_neg_integer(),
          read?: boolean(),
          write?: boolean(),
          publish?: boolean()
        }

  defstruct [:function, :arity, read?: true, write?: true, publish?: true]

  @typedoc """
  Structure of the component state.

  When a callback is executed, it may access to the state of a component instance. At the end of
  the invocation of the callback, the (possibly updated) state is returned as part of the result
  of the callback.

  This state is represented as a map, where each key corresponds to a `t:Component.field/0`. The
  value for each key corresponds to the current value of the field.
  """
  @type state :: %{optional(Component.field()) => any}

  @typedoc """
  Arguments to a callback.

  A callback is called with an arbitrary amount of arguments wrapped in a list.
  """
  @type args :: [any()]

  @typedoc """
  Function signature of a callback.

  A skitter callback accepts the state of an instance, along with the arguments to the call. The
  return value is defined by `t:result/0`.
  """
  @type signature :: (state(), args() -> Result.t())

  @typedoc """
  Properties that can be verified using `verify/2`.

  Separated into a separate type as they are used by some other functions in `Skitter.Component`.
  """
  @type property_list() :: [
          arity: non_neg_integer(),
          read?: boolean(),
          write?: boolean(),
          publish?: boolean()
        ]

  @type verify_returns ::
          :ok
          | {:error, :arity, non_neg_integer(), non_neg_integer()}
          | {:error, :read?, boolean(), boolean()}
          | {:error, :write?, boolean(), boolean()}
          | {:error, :publish?, boolean(), boolean()}

  # Utilities
  # ---------

  @doc """
  Verify the properties of a callback.

  A callback has statically known properties, such as its arity and whether it reads or writes to
  its state, that can be statically verified. This procedure accepts a keyword list of properties
  and verifies if the callback does not exceed them. If the callback violates a property, an
  `{:error, <property>, <expected value>, <actual value>}` is returned. If it does not, `:ok` is
  returned.

  The following list describes the properties and the default values that are chosen if they are
  not explicitly specified:

  - `:arity`: The expected arity of the callback. If no arity is given, any arity is accepted.
  Verified with `verify_arity/2`.
  - `:read?`: Whether or not the callback can read from the state while being executed. Defaults
  to `true`. Verified with `verify_read/2`.
  - `:write?`: Whether or not the callback can modify its state while being executed, defaults to
  `false`. Verified with `verify_write/2`.
  - `:publish?`: Whether or not the callback can publish data. Defaults to `false`. Verified with
  `verify_publish/2`.

  Note that properties are verified in the order shown above, thus, if a callback has the wrong
  arity and illegally modifies its state, `{:error, :arity, <expected>, <actual>}` will be
  returned.

  ## Examples

      iex> verify(%Callback{arity: 1, read?: true, write?: true, publish?: true}, arity: 1, read?: true, write?: true, publish?: true)
      :ok
      iex> verify(%Callback{arity: 1}, arity: 2)
      {:error, :arity, 2, 1}
      iex> verify(%Callback{read?: true}, read?: false)
      {:error, :read?, false, true}
      iex> verify(%Callback{write?: true}, write?: false)
      {:error, :write?, false, true}
      iex> verify(%Callback{write?: true})
      {:error, :write?, false, true}
      iex> verify(%Callback{write?: false, publish?: true}, publish?: false)
      {:error, :publish?, false, true}
      iex> verify(%Callback{write?: false, publish?: true})
      {:error, :publish?, false, true}
  """
  @spec verify(t(), property_list()) :: verify_returns()
  def verify(cb = %__MODULE__{}, opts \\ []) do
    arity = Keyword.get(opts, :arity, nil)
    read? = Keyword.get(opts, :read?, true)
    write? = Keyword.get(opts, :write?, false)
    publish? = Keyword.get(opts, :publish?, false)

    with {_, :ok} <- {:arity, verify_arity(cb, arity)},
         {_, :ok} <- {:read?, verify_read(cb, read?)},
         {_, :ok} <- {:write?, verify_write(cb, write?)},
         {_, :ok} <- {:publish?, verify_publish(cb, publish?)} do
      :ok
    else
      {property, {:error, expected, actual}} -> {:error, property, expected, actual}
    end
  end

  @doc """
  Verify if `callback` matches the `allowed` read capability.

  This function verifies `callback` does not attempt to read the state if it is not allowed to.
  Returns `:ok` if the read capability is not violated,
  `{:error, <expected value>, <actual value>}` otherwise.

  ## Examples

      iex> verify_read(%Callback{read?: false}, false)
      :ok
      iex> verify_read(%Callback{read?: true}, false)
      {:error, false, true}
      iex> verify_read(%Callback{read?: true}, true)
      :ok
      iex> verify_read(%Callback{read?: false}, true)
      :ok
  """
  @spec verify_read(t(), boolean()) :: :ok | {:error, boolean(), boolean()}
  def verify_read(%__MODULE__{read?: _}, true), do: :ok
  def verify_read(%__MODULE__{read?: false}, false), do: :ok
  def verify_read(%__MODULE__{read?: true}, false), do: {:error, false, true}

  @doc """
  Verify if `callback` matches the `allowed` write capability.

  This function verifies `callback` does not attempt to update the state  if it is not allowed to.
  Returns `:ok` if the write capability is not violated,
  `{:error, <expected value>, <actual value>}` otherwise.

  ## Examples

      iex> verify_write(%Callback{write?: false}, false)
      :ok
      iex> verify_write(%Callback{write?: true}, false)
      {:error, false, true}
      iex> verify_write(%Callback{write?: true}, true)
      :ok
      iex> verify_write(%Callback{write?: false}, true)
      :ok
  """
  @spec verify_write(t(), boolean()) :: :ok | {:error, boolean(), boolean()}
  def verify_write(%__MODULE__{write?: _}, true), do: :ok
  def verify_write(%__MODULE__{write?: false}, false), do: :ok
  def verify_write(%__MODULE__{write?: true}, false), do: {:error, false, true}

  @doc """
  Verify if `callback` matches the `allowed` publish capability.

  This function verifies `callback` does not attempt to publish if it is not allowed to. Returns
  `:ok` if the publish capability is not violated, `{:error, <expected value>, <actual value>}`
  otherwise.

  ## Examples

      iex> verify_publish(%Callback{publish?: false}, false)
      :ok
      iex> verify_publish(%Callback{publish?: true}, false)
      {:error, false, true}
      iex> verify_publish(%Callback{publish?: true}, true)
      :ok
      iex> verify_publish(%Callback{publish?: false}, true)
      :ok
  """
  @spec verify_publish(t(), boolean()) :: :ok | {:error, boolean(), boolean()}
  def verify_publish(%__MODULE__{publish?: _}, true), do: :ok
  def verify_publish(%__MODULE__{publish?: false}, false), do: :ok
  def verify_publish(%__MODULE__{publish?: true}, false), do: {:error, false, true}

  @doc """
  Check if the arity of a callback is equal to some value.

  Return `:ok` if the arity is equal, `{:error, <expected value>, <actual value>}` otherwise.

  ## Examples

      iex> verify_arity(%Callback{arity: 2}, 2)
      :ok
      iex> verify_arity(%Callback{arity: 3}, 2)
      {:error, 2, 3}
  """
  @spec verify_arity(t(), integer()) :: :ok | {:error, non_neg_integer(), non_neg_integer()}
  def verify_arity(%__MODULE__{arity: _}, nil), do: :ok
  def verify_arity(%__MODULE__{arity: cb}, cb), do: :ok
  def verify_arity(%__MODULE__{arity: cb}, wanted), do: {:error, wanted, cb}

  @doc """
  Invoke the callback.

  Call the given callback with `state` and `args`.

  ## Examples

  iex> call(%Callback{function: fn state, [number] ->
  ...>   %Result{result: state + number, state: state, publish: [n: number]}
  ...> end}, 1, [2])
  %Result{state: 1, publish: [n: 2], result: 3}
  """
  @spec call(t(), state(), args()) :: Result.t()
  def call(%__MODULE__{function: f}, state, args), do: f.(state, args)
end

defimpl Inspect, for: Skitter.Callback do
  use Skitter.Inspect, prefix: "Callback"

  ignore(:function)

  match(:arity, arity, _, do: "a:#{arity}")

  match(:read?, bool, _, do: "r:#{cap_str(bool)}")
  match(:write?, bool, _, do: "w:#{cap_str(bool)}")
  match(:publish?, bool, _, do: "p:#{cap_str(bool)}")

  defp cap_str(true), do: "✓"
  defp cap_str(false), do: "x"
end

defimpl Inspect, for: Skitter.Callback.Result do
  use Skitter.Inspect, prefix: "Result", named: false
  ignore_empty([:state, :publish])
end
