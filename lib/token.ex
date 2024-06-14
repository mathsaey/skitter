# Copyright 2018 - 2024, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Token do
  @moduledoc """
  Metadata tracking wrapper

  A data element being processed by a Skitter workflow is wrapped inside a _token_. This token is
  used to track additional information about the data. The Skitter runtime system stores the port
  on which the data record was received inside the token, while operations and strategies are free
  to add arbitrary meta-information.

  ## Automatic (un)wrapping

  When an operation callback is called through the use of `Skitter.Operation.call/5` or
  `Skitter.Operation.call_if_exists/5`, `wrap/1` will be used to wrap any non-token argument
  inside a token. Thus, _every_ argument accepted by a callback is always wrapped inside a token.

  The operation DSL (i.e. `Skitter.DSL.Operation.defcb/2`) automatically extracts the values from
  these tokens, and enables the meta-information contained in the tokens to be accessed through
  the use of `Skitter.DSL.Operation.port_of/1` and `Skitter.DSL.Operation.meta_of/1`.

  An operation may emit plain values or tokens, which are then received by the strategy. Any data
  emitted by the strategy (through the use of `Skitter.Strategy.Operation.emit/2` or
  `Skitter.DSL.Strategy.Helpers.emit/1`) is automatically wrapped inside a token.

  ## Available Information

  ### Port

  When a data record is provided to a strategy through `c:Skitter.Strategy.Operation.deliver/2`,
  the Skitter runtime system ensures that the data record is wrapped inside a token which stores
  the `port` on which the token was received. If this token is passed to an operation callback
  unmodified, `Skitter.DSL.Operation.port_of/1` can be used to obtain this port.

  ### Meta-information

  An operation or strategy may add arbitrary meta-information to a token. This information can be
  used to track application-specific concerns such as timing information (used to implement
  windowing support). The Skitter runtime system does not handle this information in any way.
  It is therefore up to the developers of operations and strategies to ensure that this
  information is not lost.
  """
  alias Skitter.Operation

  @typedoc """
  Values tracked by a token.

  A token tracks the value it wraps (`:value`), the port on which the value was received
  (`:port`), and a collection of arbitrary meta-information (`:meta`). The meta-information is
  stored as key-value pairs.
  """
  @type t :: %__MODULE__{
          value: any(),
          port: Operation.port_name() | nil,
          meta: %{optional(atom()) => any()}
        }
  @enforce_keys [:value]
  defstruct value: nil, port: nil, meta: %{}

  @doc """
  Extract the value from a token.

  Get the value from a token, or return a value if no token is provided.

  ## Examples

      iex> unwrap(%Token{value: 5})
      5
      iex> unwrap(5)
      5
  """
  @spec unwrap(t() | any()) :: any()
  def unwrap(%__MODULE__{value: v}), do: v
  def unwrap(v), do: v

  @doc """
  Wrap a value in a token.

  This operation is a no-op if it receives a token. Otherwise, it wraps the value inside a token
  with no port and empty meta-information.

  ## Examples

      iex> wrap(%Token{value: 5, port: :foo, meta: %{window: 10}})
      %Token{value: 5, port: :foo, meta: %{window: 10}}
      iex> wrap(5)
      %Token{value: 5, port: nil, meta: %{}}
  """
  @spec wrap(t() | any()) :: t()
  def wrap(t = %__MODULE__{}), do: t
  def wrap(v), do: %__MODULE__{value: v}

  @doc """
  Set the meta-information of a token or value.

  This function associates meta-information with a token. If a plain value is provided, it is
  wrapped in a token first. If a token with existing meta-information is provided, the existing
  meta-information is overwritten.

  ## Examples

      iex> with_meta(%Token{value: 5, port: :foo, meta: %{window: 10}}, foo: :bar, window: 20)
      %Token{value: 5, port: :foo, meta: %{window: 20, foo: :bar}}
      iex> with_meta(5, foo: :bar, window: 20)
      %Token{value: 5, port: nil, meta: %{window: 20, foo: :bar}}
  """
  @spec with_meta(t() | any(), keyword()) :: t()
  def with_meta(t, meta), do: %{wrap(t) | meta: Map.new(meta)}

  @doc """
  Add meta-information to a token or value.

  This function stores a key-value pair in the meta-information of a token. If a plain value is
  provided, it is wrapped inside a token first. If a value was present for `key` in the
  meta-information of token, it is overwritten.

  ## Examples

      iex> put_meta(%Token{value: 5, port: :foo, meta: %{window: 10}}, :foo, :bar)
      %Token{value: 5, port: :foo, meta: %{window: 10, foo: :bar}}
      iex> put_meta(%Token{value: 5, port: :foo, meta: %{window: 10}}, :window, 20)
      %Token{value: 5, port: :foo, meta: %{window: 20}}
      iex> put_meta(5, :foo, :bar)
      %Token{value: 5, port: nil, meta: %{foo: :bar}}
  """
  @spec put_meta(t() | any(), atom(), any()) :: t()
  def put_meta(token, key, value)
  def put_meta(t = %__MODULE__{}, key, value), do: %{t | meta: Map.put(t.meta, key, value)}
  def put_meta(v, key, value), do: %__MODULE__{value: v, meta: %{key => value}}

  @doc """
  Update meta-information associated with a value.

  This function obtains the value for `key` stored inside the meta-information of a token and
  passes it to the provided function. The result of the function is stored as the new value for
  `key` in the meta-information of the token.

  If a plain value is provided, the value is wrapped inside a token first. In this case, or if
  `key` does not exist in the meta-information of the provided token, the function is called with
  value `nil`.

  ## Examples

      iex> update_meta(%Token{value: 5, port: :foo, meta: %{window: 10}}, :window, fn
      ...>   nil -> 0
      ...>   window -> window + 10
      ...> end)
      %Token{value: 5, port: :foo, meta: %{window: 20}}
      iex> update_meta(%Token{value: 5, port: :foo, meta: %{foo: :bar}}, :window, fn
      ...>   nil -> 0
      ...>   window -> window + 10
      ...> end)
      %Token{value: 5, port: :foo, meta: %{window: 0, foo: :bar}}
      iex> update_meta(5, :window, fn
      ...>   nil -> 0
      ...>   window -> window + 10
      ...> end)
      %Token{value: 5, port: nil, meta: %{window: 0}}
  """
  @spec update_meta(t() | any(), atom(), (any() -> any())) :: t()
  def update_meta(token, key, fun)
  def update_meta(t = %__MODULE__{}, k, f), do: %{t | meta: Map.put(t.meta, k, f.(t.meta[k]))}
  def update_meta(v, key, fun), do: %__MODULE__{value: v, meta: %{key => fun.(nil)}}
end
