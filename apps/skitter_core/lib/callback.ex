# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Callback do
  @moduledoc """
  Representation of a component callback.

  A callback is a piece of code which implements some functionality of a
  `Skitter.Component`. Internally, a callback is defined as an anonymous
  function and some metadata.

  This module defines the internal representation of a callback and contains
  some utilities to manipulate callbacks.
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

    When a callback publishes data it returns the published data as a keyword
    list. The keys in this list represent the names of output ports; the values
    of the keys represent the data to be publish on an output port.
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
            state: Callback.state(),
            publish: publish(),
            result: any()
          }

    defstruct [:state, :publish, :result]
  end

  @typedoc """
  Callback representation.

  A callback is defined as a function with type `t:signature`, which implements
  the functionality of the callback and a set of metadata which define the
  capabilities of the callback, and store its arity.

  The capabilities of a callback specify how a callback accesses its state and
  wither or not it publishes data.
  """
  @type t :: %__MODULE__{
          function: signature(),
          arity: non_neg_integer(),
          state_capability: state_capability(),
          publish_capability: publish_capability()
        }

  defstruct [:function, :arity, :state_capability, :publish_capability]

  @typedoc """
  Result returned by the invocation of a callback.

  A successful callback returns a `t:Result.t/0` struct, which contains the
  updated state, published data and result value of the callback.
  When not successful, the callback returns an `{:error, reason}` tuple.
  """
  @type result :: Result.t() | {:error, any()}

  @typedoc """
  Structure of the component state.

  When a callback is executed, it may access to the state of a component
  instance (see `t:Callback.state_capability/0`). At the end of the
  invocation of the callback, the (possibly updated) state is returned as
  part of the result of
  the callback.

  This state is represented as a map, where each key corresponds to a
  `t:Component.field/0`. The value for each key corresponds to the current
  value of the field.
  """
  @type state :: %{optional(Component.field()) => any}

  @typedoc """
  Function signature of a callback.

  A skitter callback accepts the state of an instance, along with an arbitrary
  amount of arguments wrapped in a list. The return value is defined by
  `t:result/0`.
  """
  @type signature :: (state(), [any()] -> result())

  @typedoc """
  Defines how the callback may access the state.

  - `:none`: The callback never accesses the state.
  - `:read`: The callback reads the state but never modifies it.
  - `:readwrite`: The callback may read and update the state.
  """
  @type state_capability :: :none | :read | :readwrite

  @typedoc """
  Defines if the callback can publish data.

  `true` if the callback may publish data.
  """
  @type publish_capability :: boolean()

  # Utilities
  # ---------

  @doc """
  Verify if `callback` matches the `allowed` state capability.

  This function verifies `callback` does not exceed the `allowed` state capability. A callback
  exceeds `allowed` if its `state_capability` is higher than `allowed`. To verify this, the
  following order is used: `:none < :read < :readwrite`.

  ## Examples

      iex> state_permission?(%Callback{state_capability: :none}, :readwrite)
      true
      iex> state_permission?(%Callback{state_capability: :readwrite}, :none)
      false
      iex> state_permission?(%Callback{state_capability: :read}, :read)
      true
      iex> state_permission?(%Callback{state_capability: :readwrite}, :read)
      false
  """
  @spec state_permission?(t(), state_capability()) :: boolean()
  def state_permission?(%__MODULE__{state_capability: capability}, allowed) do
    state_order(capability) <= state_order(allowed)
  end

  defp state_order(:none), do: 0
  defp state_order(:read), do: 1
  defp state_order(:readwrite), do: 2

  @doc """
  Verify if `callback` matches the `allowed` publish capability.

  This function verifies `callback` does not attempt to publish if it is not allowed to.

  ## Examples

      iex> publish_permission?(%Callback{publish_capability: false}, false)
      true
      iex> publish_permission?(%Callback{publish_capability: true}, false)
      false
      iex> publish_permission?(%Callback{publish_capability: true}, true)
      true
      iex> publish_permission?(%Callback{publish_capability: false}, true)
      true
  """
  @spec publish_permission?(t(), publish_capability()) :: boolean()
  def publish_permission?(%__MODULE__{publish_capability: _}, true), do: true
  def publish_permission?(%__MODULE__{publish_capability: false}, false), do: true
  def publish_permission?(%__MODULE__{publish_capability: true}, false), do: false

  @doc """
  Check if the arity of a callback is equal to some value.

  This function is mainly useful to check the arity of a callback when using
  the `|>` syntax.

  ## Examples

      iex> has_arity?(%Callback{arity: 2}, 2)
      true
      iex> has_arity?(%Callback{arity: 3}, 2)
      false
  """
  @spec has_arity?(t(), integer()) :: boolean()
  def has_arity?(%__MODULE__{arity: cb}, wanted), do: cb == wanted

  @doc """
  Invoke the callback.

  Call the given callback with `state` and `args`.

  ## Examples

  iex> call(%Callback{function: fn state, [number] ->
  ...>   %Result{result: state + number, state: state, publish: [n: number]}
  ...> end}, 1, [2])
  %Result{state: 1, publish: [n: 2], result: 3}
  """
  @spec call(t(), state(), [any()]) :: result()
  def call(%__MODULE__{function: f}, state, args), do: f.(state, args)
end

defimpl Inspect, for: Skitter.Callback do
  use Skitter.Inspect, prefix: "Callback"

  ignore(:function)

  match(:arity, arity, _, do: "arity[#{arity}]")

  match(:state_capability, state, _) do
    "state_capability[#{state_cap_str(state)}]"
  end

  match(:publish_capability, pub, _) do
    "publish_capability[#{publish_cap_str(pub)}]"
  end

  defp state_cap_str(:none), do: "/"
  defp state_cap_str(:read), do: "R"
  defp state_cap_str(:readwrite), do: "RW"
  defp state_cap_str(_), do: "?"

  defp publish_cap_str(true), do: "✓"
  defp publish_cap_str(false), do: "x"
  defp publish_cap_str(_), do: "?"
end

defimpl Inspect, for: Skitter.Callback.Result do
  use Skitter.Inspect, prefix: "Result", named: false
  ignore_empty([:state, :publish])
end
