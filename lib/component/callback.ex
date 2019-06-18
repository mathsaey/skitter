# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Callback do
  @moduledoc """
  Representation of a component callback.

  A callback is a piece of code which implements some functionality of a
  `Skitter.Component`. Internally, a callback is defined as an anonymous
  function and some metadata.
  """
  alias Skitter.{Component, Port}

  defstruct [:function, :state_capability, :publish_capability]

  @typedoc """
  Callback representation.

  A callback is defined as a function with type `t:signature`, which implements
  the functionality of the callback and a set of metadata which define the
  capabilities of the callback.

  The following capabilities are defined:

  - `state_capability`: Defines if the callback is allowed to read or write the
  state of the component instance.
  - `publish_capability`: Defines if the callback may publish data
  """
  @type t :: %__MODULE__{
          function: signature(),
          state_capability: state_capability(),
          publish_capability: publish_capability()
        }

  @typedoc """
  Structure of published data.

  When a callback publishes data it returns the published data as a keyword
  list. The keys in this list represent the names of output ports; the values
  of the keys represent the data to be publish on an output port.
  """
  @type publish :: [{Port.t(), any()}]

  @typedoc """
  Result returned by the invocation of a callback.

  A successful callback is a four tuple which starts with `:ok`. Besides `:ok`,
  the callback returns the new state of the component instance, the data to be
  published and the result of the callback. `nil` can be provided instead of
  the state or published data if the callback does not update the instance
  state, or if it does not publish any data.
  When not successful, the callback returns an `{:error, reason}` tuple.
  """
  @type result ::
          {:ok, Component.state() | nil, publish() | nil, any()}
          | {:error, any()}

  @typedoc """
  Function signature of a callback.

  A skitter callback accepts the state of an instance, along with an arbitrary
  amount of arguments wrapped in a list. The return value is defined by
  `t:result/0`.
  """
  @type signature :: (Component.state(), [any()] -> result())

  @typedoc """
  Defines how the callback may access the state.
  """
  @type state_capability :: :none | :read | :readwrite

  @typedoc """
  Defines if the callback can publish data.
  """
  @type publish_capability :: boolean()

  @doc """
  Create a callback. Arguments are identical to `t:t/0`.
  """
  @spec create(signature(), state_capability(), publish_capability()) :: t()
  def create(func, state_capability, publish_capability) do
    %__MODULE__{
      function: func,
      state_capability: state_capability,
      publish_capability: publish_capability
    }
  end

  @doc """
  Check if the callback adheres to its capabilities.

  Concretely, this means that the callback does not access the state or publish
  data when it is not allowed to.

  Note that a callback may have a permission without using it. E.g. a callback
  may have a `:readwrite` state capability and only read the state or not
  access it at all.

  ## Examples

      iex> check_permissions(
      ...>  %Callback{state_capability: :read, publish_capability: true},
      ...>  :readwrite,
      ...>  true
      ...> )
      true
      iex> check_permissions(
      ...>  %Callback{state_capability: :read, publish_capability: true},
      ...>  :none,
      ...>  true
      ...> )
      false
      iex> check_permissions(
      ...>  %Callback{state_capability: :none, publish_capability: true},
      ...>  :none,
      ...>  false
      ...> )
      false
      iex> check_permissions(
      ...>  %Callback{state_capability: :none, publish_capability: false},
      ...>  :none,
      ...>  false
      ...> )
      true
  """
  @spec check_permissions(t(), state_capability(), boolean()) :: boolean()
  def check_permissions(
        cb = %__MODULE__{},
        state_capability,
        publish_capability
      ) do
    state_order(cb.state_capability) <= state_order(state_capability) and
      (cb.publish_capability == publish_capability or publish_capability)
  end

  defp state_order(:none), do: 0
  defp state_order(:read), do: 1
  defp state_order(:readwrite), do: 2

  @doc """
  Call the callback.

  ## Examples

      iex> cb = %Callback{
      ...>  function: fn s, [a, b] -> {:ok, s, [out: s.f + a], b} end}
      iex> call(cb, %{f: 1}, [2, 3])
      {:ok, %{f: 1}, [out: 3], 3}
  """
  @spec call(t(), Component.state(), [any()]) :: result()
  def call(%__MODULE__{function: f}, state, args), do: f.(state, args)
end
