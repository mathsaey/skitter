# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Callback do
  @moduledoc """
  Function which implements the logic of a `Skitter.Component`.

  A callback is defined as an elixir function which implements the data processing logic of a
  `Skitter.Component`. Components need to be able to publish data and modify state when called.
  Therefore, callback functions always accept a state as their first argument. They also return a
  `t:result/0`, which wraps the result of the callback call along with the updated state and
  modified data.

  A callback track additional information about the state it updates and the data it publishes.
  This information is stored inside the component module where the callback is defined. The
  behaviour defined in this module defines the functions that should be implemented to store this
  information. Instead of implementing these functions manually, it is recommend to use
  `Skitter.DSL.Component.Callback.defcb/2`, which does this automatically.

  This module defines the callback type and behaviour along with some utilities to handle
  callbacks.

  ## Examples

  Since callbacks need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ModuleWithCallbacks do
    @behaviour Skitter.Component.Callback
    alias Skitter.Component.Callback.{Result, Info}

    def _sk_callback_list, do: [example: 1]

    def _sk_callback_info(:example, 1) do
      %Info{read: [:field], write: [], publish: [:arg]}
    end

    def example(state, arg) do
      result = Map.get(state, :field)
      %Result{state: state, publish: [arg: arg], result: result}
    end
  end
  ```
  """
  alias Skitter.{Port, Component, DefinitionError}

  # ---------------- #
  # Type & Behaviour #
  # ---------------- #

  @typedoc """
  Module in which the callback is embedded.

  Currently, only component modules store callbacks.
  """
  @type parent :: Component.t()

  @typedoc """
  Arguments passed to a callback when it is called.

  The arguments are wrapped in a list.
  """
  @type args :: [any()]

  @typedoc """
  State passed to the callback when it is called.

  The state is wrapped in a dictionary.
  """
  @type state :: %{optional(atom()) => any()}

  @typedoc """
  Values returned by a callback when it is called.

  The following information is stored:

  - `:result`: The actual result of the callback, i.e. the final value returned in its body.
  - `:state`: The (possibly modified) state after calling the callback.
  - `:publish`: The list of output published by the callback.
  """
  @type result :: %__MODULE__.Result{
          result: any(),
          state: state(),
          publish: [{Port.t(), any()}]
        }

  @typedoc """
  Additional callback information. Can be retrieved with `info/2`.

  The following information is stored:

  - `:read`: The state fields read inside the callback.
  - `:write`: The state fields updated by the callback.
  - `:publish`: The ports this callback published to.
  """
  @type info :: %__MODULE__.Info{
          read: [atom()],
          write: [atom()],
          publish: [atom()]
        }

  @doc """
  Return the callback information of callback `name`, `arity`.
  """
  @callback _sk_callback_info(name :: atom(), arity()) :: info()

  @doc """
  Return a list with the names of all the callbacks defined in this module.
  """
  @callback _sk_callback_list() :: [{atom(), arity()}]

  # Struct Definitions
  # ------------------

  defmodule Result do
    @moduledoc false
    defstruct [:state, :publish, :result]
  end

  defmodule Info do
    @moduledoc false
    defstruct read: [], write: [], publish: []
  end

  # --------- #
  # Utilities #
  # --------- #

  @doc """
  Call the specified callback with `args` and `state`.

  ## Examples

      iex> call(ModuleWithCallbacks, :example, %{field: "Skitter"}, [:some_argument])
      %Result{state: %{field: "Skitter"}, publish: [arg: :some_argument], result: "Skitter"}

  """
  @spec call(parent(), atom(), state(), args()) :: result()
  def call(parent, name, state, args), do: apply(parent, name, [state | args])

  @doc false
  # Slightly more efficient version of call/4, can only be used when the "shape" of argument is
  # known upfront. Mainly used by the runtime system to call strategy hooks.
  defmacro call_inlined(parent, name, state, args) do
    quote do
      unquote(parent).unquote(name)(unquote(state), unquote_splicing(args))
    end
  end

  @doc """
  Obtain the callback information for callback `name`, `arity` in `parent`.

  ## Examples

      iex> info(ModuleWithCallbacks, :example, 1)
      %Info{read: [:field], write: [], publish: [:arg]}

  """
  @spec info(parent(), atom(), arity()) :: info()
  def info(parent, name, arity), do: parent._sk_callback_info(name, arity)

  @doc """
  Obtain the list of all callbacks defined in `parent`.

  ## Examples

      iex> list(ModuleWithCallbacks)
      [example: 1]

  """
  @spec list(parent()) :: [{atom(), arity()}]
  def list(parent), do: parent._sk_callback_list()

  @doc """
  Verify if the `property` of the provided `info` satisfies `property`

  This function will lookup the property of a callback in the provided `t:info/0` struct and
  compare it to an expected value.

  - If the property is not present in `t:info/0`, `:invalid` is returned.

  - If the property has the same value as `expected`, `:ok` is returned.

  - If the values do not match, the actual value of the property is returned.

  As a special case, the properties, `read?`, `write?` and `publish?` may be passed along with a
  boolean value. When this value is `false`, `verify` ensures the corresponding property (`read`,
  `write`, or `publish`) is equal to the empty list. When `true` is passed, any value for `read`,
  `write` or `publish` is accepted. This is done to enable `verify/3` to ensure a callback does
  not update its state or publish data when this is not allowed.

  ## Examples

      iex> verify(%Info{read: [:field]}, :read, [:field])
      :ok

      iex> verify(%Info{read: [:field]}, :read, [])
      [:field]

      iex> verify(%Info{read: [:field]}, :red, [:field])
      :invalid

      iex> verify(%Info{read: [:field]}, :read?, true)
      :ok

      iex> verify(%Info{read: [:field]}, :read?, false)
      [:field]

      iex> verify(%Info{write: []}, :write?, true)
      :ok

      iex> verify(%Info{write: []}, :write?, false)
      :ok

  """
  @spec verify(info(), atom(), any()) :: :ok | :invalid | any()

  def verify(_, property, true) when property in [:read?, :write?, :publish?], do: :ok

  def verify(info = %Info{}, :read?, false), do: verify(info, :read, [])
  def verify(info = %Info{}, :write?, false), do: verify(info, :write, [])
  def verify(info = %Info{}, :publish?, false), do: verify(info, :publish, [])

  def verify(info = %Info{}, property, expected) do
    case Map.get(info, property) do
      nil -> :invalid
      ^expected -> :ok
      value -> value
    end
  end

  @doc """
  Verify if the `property` of a callback satisfies `property`

  Works like `verify/3`, but raises a `Skitter.DefinitionError` if the properties do not match.
  `:ok` is returned if the properties match.

  ## Examples

      iex> verify!(%Info{write: []}, :write, [], "example")
      :ok

      iex> verify!(%Info{write: []}, :write, [:field], "example")
      ** (Skitter.DefinitionError) Incorrect write for callback example, expected [:field], got []

      iex> verify!(%Info{write: []}, :wrte, [], "example")
      ** (Skitter.DefinitionError) `wrte` is not a valid property name

      iex> verify!(%Info{read: []}, :read?, true, "example")
      :ok

      iex> verify!(%Info{read: [:field]}, :read?, false, "example")
      ** (Skitter.DefinitionError) Incorrect read for callback example, expected [], got [:field]

      iex> verify!(%Info{read: []}, :write?, true, "example")
      :ok

      iex> verify!(%Info{read: []}, :write?, false, "example")
      :ok

  """
  @spec verify!(info(), atom(), any(), String.t()) :: :ok | no_return()

  def verify!(_, property, true, _) when property in [:read?, :write?, :publish?], do: :ok

  def verify!(info = %Info{}, :read?, false, name), do: verify!(info, :read, [], name)
  def verify!(info = %Info{}, :write?, false, name), do: verify!(info, :write, [], name)
  def verify!(info = %Info{}, :publish?, false, name), do: verify!(info, :publish, [], name)

  def verify!(info = %Info{}, property, value, name) do
    case verify(info, property, value) do
      :ok ->
        :ok

      :invalid ->
        raise DefinitionError, "`#{property}` is not a valid property name"

      actual ->
        value = inspect(value)
        actual = inspect(actual)

        raise DefinitionError,
              "Incorrect #{property} for callback #{name}, expected #{value}, got #{actual}"
    end
  end

  @doc """
  Verify the properties of a callback using `verify!/4`.

  This function accepts a keyword list of `{property, expected_value}` pairs and compares each of
  them with `verify!/4`.

  ## Examples

      iex> verify!(%Info{read: [], write: [:field]}, "example", read?: true, write?: true)
      :ok

      iex> verify!(%Info{read: [], write: [:field]}, "example")
      :ok

      iex> verify!(%Info{write: [:field]}, "example", publish?: true, wrt: [])
      ** (Skitter.DefinitionError) `wrt` is not a valid property name

      iex> verify!(%Info{publish: [:port]}, "example", publish?: false)
      ** (Skitter.DefinitionError) Incorrect publish for callback example, expected [], got [:port]
  """
  @spec verify!(info(), String.t(), [{atom(), any()}]) :: :ok | no_return()
  def verify!(info = %Info{}, name, properties \\ []) do
    Enum.each(properties, fn {property, value} -> verify!(info, property, value, name) end)
  end
end
