# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Reactive Component definition and utilities.

  A Reactive Component is one of the core building blocks of skitter.  It defines a single data
  processing step which can be embedded inside a reactive workflow.

  This module defines the internal representation of a skitter component as an elixir struct
  (`t:t/0`), some utilities to manipulate components and the `Access` behaviour for `t:t/0`. This
  behaviour can be used to access and modify a callback with a given name.
  """
  alias Skitter.{Port, Callback, Component, Strategy}

  @behaviour Access

  @typedoc """
  A component is defined as a collection of _metadata_ and _callbacks_.

  The metadata provides additional information about a component, while the various `Callback`
  implement the functionality of a component.

  The following metadata is stored:

  | Name          | Description                                  | Default   |
  | ------------- | -------------------------------------------- | --------- |
  | `name`        | The name of the component                    | `nil`     |
  | `fields`      | List of the slots of the component           | `[]`      |
  | `in_ports`    | List of in ports of the component.           | `[]`      |
  | `out_ports`   | List of out ports of the component           | `[]`      |
  | `strategy`    | The `t:Skitter.Strategy/0` of this component | `nil`     |

  Note that a valid component must have at least one in port.
  """
  @type t :: %__MODULE__{
          name: module() | nil,
          fields: [field()],
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          callbacks: %{optional(callback_name()) => Callback.t()},
          strategy: Strategy.t()
        }

  defstruct name: nil,
            fields: [],
            in_ports: [],
            out_ports: [],
            callbacks: %{},
            strategy: nil

  @typedoc """
  Data storage "slot" of a component.

  The state of a component instance is divided into various named slots.  In skitter, these slots
  are called _fields_. The fields of a component are statically defined and are stored as atoms.
  """
  @type field :: atom()

  @typedoc """
  Callback identifiers.

  The callbacks of a skitter component are named.  These names are stored as atoms.
  """
  @type callback_name :: atom()

  # --------- #
  # Utilities #
  # --------- #

  @doc """
  Call a specific callback of the component.

  Call the callback named `callback_name` of `component` with the arguments defined in
  `t:Callback.signature/0`.

  ## Examples

      iex> cb = %Callback{function: fn _, _ -> %Result{result: 10} end}
      iex> call(%Component{callbacks: %{f: cb}}, :f, %{}, [])
      %Callback.Result{state: nil, publish: nil, result: 10}
  """
  @spec call(t(), callback_name(), Callback.state(), [any()]) ::
          Callback.result()
  def call(component = %Component{}, callback_name, state, arguments) do
    Callback.call(component[callback_name], state, arguments)
  end

  @doc """
  Create an initial `t:Callback.state/0` for a given component.

  ## Examples

      iex> create_empty_state(%Component{fields: [:a_field, :another_field]})
      %{a_field: nil, another_field: nil}
      iex> create_empty_state(%Component{fields: []})
      %{}
  """
  @spec create_empty_state(Component.t()) :: Callback.state()
  def create_empty_state(%Component{fields: fields}) do
    Map.new(fields, &{&1, nil})
  end

  @doc """
  Add `callback` to `component` with `name`, if `component[name]` is undefined.

  ## Examples

      iex> foo_cb = %Callback{function: fn _, _ -> %Result{result: :foo} end}
      iex> bar_cb = %Callback{function: fn _, _ -> %Result{result: :bar} end}
      iex> comp = %Component{callbacks: %{foo: foo_cb}}
      ...>   |> default_callback(:foo, bar_cb)
      ...>   |> default_callback(:bar, bar_cb)
      iex> call(comp, :foo, %{}, []).result
      :foo
      iex> call(comp, :bar, %{}, []).result
      :bar
  """
  @spec default_callback(t(), callback_name(), Callback.t()) :: t()
  def default_callback(component = %Component{callbacks: map}, name, callback) do
    if map[name] do
      component
    else
      %{component | callbacks: Map.put(map, name, callback)}
    end
  end

  @doc """
  Verify if `component` defines a callback with `name` and correct attributes.

  The attributes are defined in `opts`, which may contain the expected arity, state_capability and
  publish_capability of the callback.

  - `:arity` is checked with `Skitter.Callback.has_arity?/2` If no `arity` option is given, any
  arity is accepted.
  - `:state_capability` is checked with `Callback.state_permission?/2`. If no `state_capability`
  option is given, it defaults to `:none`.
  - `:publish_capability` is checked with `Callback.publish_permission?/2`. If no
  `publish_capability` option is given, it defaults to `false`.

  ## Examples

      iex> cb1 = %Callback{arity: 1, state_capability: :none, publish_capability: false}
      iex> require_callback(%Component{callbacks: %{foo: cb1}}, :foo)
      :ok
      iex> require_callback(%Component{callbacks: %{}}, :foo)
      {:error, :undefined}
      iex> require_callback(%Component{callbacks: %{foo: cb1}}, :foo, arity: 2)
      {:error, :arity, 2, 1}
      iex> cb2 = %Callback{arity: 1, state_capability: :read, publish_capability: true}
      iex> require_callback(%Component{callbacks: %{foo: cb2}}, :foo)
      {:error, :publish_capability, false, true}
      iex> require_callback(%Component{callbacks: %{foo: cb2}}, :foo, publish_capability: true)
      {:error, :state_capability, :none, :read}
      iex> require_callback(%Component{callbacks: %{foo: cb2}}, :foo, publish_capability: true, state_capability: :readwrite)
      :ok
  """
  @spec require_callback(t(), callback_name(),
          arity: non_neg_integer(),
          state_capability: Callback.state_capability(),
          publish_capability: Callback.publish_capability()
        ) ::
          :ok
          | {:error, :undefined}
          | {:error, :arity, non_neg_integer(), non_neg_integer()}
          | {:error, :publish_capability, boolean(), boolean()}
          | {:error, :state_capability, Callback.state_capability(), Callback.state_capability()}
  def require_callback(%Component{callbacks: map}, name, opts \\ []) do
    arity = Keyword.get(opts, :arity, nil)
    state = Keyword.get(opts, :state_capability, :none)
    publish = Keyword.get(opts, :publish_capability, false)

    with {_, cb = %Callback{}} <- {:defined, map[name]},
         {_, true} <- {:arity, if(arity, do: arity == cb.arity, else: true)},
         {_, true} <- {:publish, Callback.publish_permission?(cb, publish)},
         {_, true} <- {:state, Callback.state_permission?(cb, state)} do
      :ok
    else
      {:defined, _} -> {:error, :undefined}
      {:arity, false} -> {:error, :arity, arity, map[name].arity}
      {:state, false} -> {:error, :state_capability, state, map[name].state_capability}
      {:publish, false} -> {:error, :publish_capability, publish, map[name].publish_capability}
    end
  end

  @doc """
  Return `component` if it defines a callback with `name`, raise otherwise.

  This function uses `require_callback/3` under the hood. However, since it returns `component`
  when successful it can easily be used inside `|>` pipelines. If `require_callback/3` is not
  successful, a `Skitter.StrategyError` is raised.

  Please refer to the documentation of `require_callback/3` for more information.

  Please read the documentation of `require_callback/3` to obtain information about `opts`.

  ## Examples

      iex> cb = %Callback{arity: 1, state_capability: :none, publish_capability: false}
      iex> require_callback!(%Component{callbacks: %{foo: cb}}, :foo)
      %Component{callbacks: %{foo: %Callback{arity: 1, publish_capability: false, state_capability: :none}}}

      iex> require_callback!(%Component{callbacks: %{}}, :foo)
      ** (Skitter.StrategyError) Missing implementation of required callback: `foo`

      iex> cb = %Callback{arity: 1, state_capability: :none, publish_capability: false}
      iex> require_callback!(%Component{callbacks: %{foo: cb}}, :foo, arity: 2)
      ** (Skitter.StrategyError) Incorrect arity for callback `foo`, expected 2, got 1

      iex> cb = %Callback{arity: 1, state_capability: :read, publish_capability: true}
      iex> require_callback!(%Component{callbacks: %{foo: cb}}, :foo)
      ** (Skitter.StrategyError) Incorrect publish_capability for callback `foo`, expected false, got true

      iex> cb = %Callback{arity: 1, state_capability: :readwrite, publish_capability: false}
      iex> require_callback!(%Component{callbacks: %{foo: cb}}, :foo, state_capability: :read)
      ** (Skitter.StrategyError) Incorrect state_capability for callback `foo`, expected read, got readwrite
  """
  @spec require_callback!(t(), callback_name(),
          arity: non_neg_integer(),
          state_capability: Callback.state_capability(),
          publish_capability: Callback.publish_capability()
        ) :: t() | no_return()
  def require_callback!(component, name, opts \\ []) do
    case require_callback(component, name, opts) do
      :ok ->
        component

      {:error, :undefined} ->
        Skitter.StrategyError.raise("Missing implementation of required callback: `#{name}`")

      {:error, attr, wanted, actual} ->
        Skitter.StrategyError.raise(
          "Incorrect #{attr} for callback `#{name}`, expected #{wanted}, got #{actual}"
        )
    end
  end

  # Access
  # ------

  @impl true
  def fetch(comp, key), do: Access.fetch(comp.callbacks, key)

  @impl true
  def pop(comp, key) do
    {val, cbs} = Access.pop(comp.callbacks, key)
    {val, %{comp | callbacks: cbs}}
  end

  @impl true
  def get_and_update(comp, key, f) do
    {val, cbs} = Access.get_and_update(comp.callbacks, key, f)
    {val, %{comp | callbacks: cbs}}
  end
end

defimpl Inspect, for: Skitter.Component do
  use Skitter.Inspect, prefix: "Component", named: true

  ignore_short([:callbacks, :fields, :handler])
  ignore_empty([:fields, :out_ports])

  describe(:in_ports, "in")
  describe(:out_ports, "out")
end
