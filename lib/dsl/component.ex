# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component do
  @moduledoc """
  Component definition DSL. See `defcomponent/3`.

  This module offers the `defcomponent/3` macro, which enables the definition of a
  `Skitter.Component` module. To use this macro, simply `import` this module, after which
  `defcomponent/3` can be used.
  """
  alias Skitter.DSL.AST
  alias Skitter.DefinitionError

  @doc """
  Define the fields of the component's state.

  This macro defines the various fields that make up the state of a component. It is used
  similarly to `defstruct/1`. You should only use this macro once inside the body of a component.
  Note that an empty state will automatically be generated if this macro is not used.

  ## Internal representation as a struct

  Currently, this macro is syntactic sugar for directly calling `defstruct/1`. Programmers should
  not rely on this property however, as it may change in the future. The use of `fields/1` is
  preferred as it decouples the definition of the layout of a state from its internal
  representation as an elixir struct.

  ## Examples

  Assume the definition of a `FieldsExample` component with fields: `fields foo: 42`:

      iex> Component.create_empty_state(FieldsExample)
      %FieldsExample{foo: 42}

  If a component `NoFields` does not specify a fields declaration:

      iex> Component.create_empty_state(NoFields)
      %NoFields{}

  When multiple `fields` declarations are present, a `Skitter.DefinitionError` will be raised.
  """
  defmacro fields(lst) do
    quote do
      defstruct unquote(lst)
    end
  end

  @doc """
  Define a component module.

  This macro is used to define a component module. Using this macro, a component can be defined
  similar to a normal module. The macro will automatically include the callback DSL, ensure a
  struct is defined to represent the component's state and provide implementations for
  `c:Skitter.Component._sk_component_info/1`.

  ## Component strategy and ports

  The component Strategy and its in -and out ports can be defined in the header of the component
  declaration as follows:

      iex> defcomponent SignatureExample, in: [a, b, c], out: [y, z], strategy: SomeStrategy do
      ...> end
      iex> Component.strategy(SignatureExample)
      SomeStrategy
      iex> Component.in_ports(SignatureExample)
      [:a, :b, :c]
      iex> Component.out_ports(SignatureExample)
      [:y, :z]

  If a component has no `in`, or `out` ports, it can be omitted from the component's header.
  Furthermore, if only a single `in` or `out` port, the list notation can be omitted:

      iex> defcomponent PortExample, in: a, strategy: SomeStrategy do
      ...> end
      iex> Component.in_ports(PortExample)
      [:a]
      iex> Component.out_ports(PortExample)
      []

  Finally, note that it is mandatory to specify the component's strategy:

  ```
  defcomponent NoStrategy do
  end
  ```

  will raise a `Skitter.DefinitionError`

  ## Examples

  ```
  defcomponent Average, in: value, out: current, strategy: SomeStrategy do
    fields total: 0, count: 0

    defcb react(value) do
      total <~ ~f{total} + value
      count <~ ~f{count} + 1

      ~f{total} / ~f{count} ~> current
    end
  end
  ```

      iex> Component.in_ports(Average)
      [:value]
      iex> Component.out_ports(Average)
      [:current]
      iex> Component.strategy(Average)
      SomeStrategy
      iex> Component.call(Average, :react, [10])
      %Result{result: 10.0, publish: [current: 10.0], state: %Average{count: 1, total: 10}}
      iex> Component.call(Average, :react, %Average{count: 1, total: 10}, [10])
      %Result{result: 10.0, publish: [current: 10.0], state: %Average{count: 2, total: 20}}

  """
  defmacro defcomponent(name, opts \\ [], do: body) do
    in_ = opts |> Keyword.get(:in, []) |> AST.names_to_atoms()
    out = opts |> Keyword.get(:out, []) |> AST.names_to_atoms()

    strategy = opts |> Keyword.get(:strategy) |> read_strategy(__CALLER__)

    fields_ast =
      case AST.count_uses(body, :fields) do
        0 -> quote do: defstruct([])
        1 -> quote do: nil
        _ -> DefinitionError.inject("Only one fields declaration is allowed", __CALLER__)
      end

    quote do
      defmodule unquote(name) do
        use Skitter.DSL.Callback
        @behaviour Skitter.Component

        import unquote(__MODULE__), only: [fields: 1]

        unquote(strategy)
        def _sk_component_info(:in_ports), do: unquote(in_)
        def _sk_component_info(:out_ports), do: unquote(out)

        unquote(fields_ast)
        unquote(body)
      end
    end
  end

  defp read_strategy(nil, env), do: DefinitionError.inject("Missing strategy", env)

  defp read_strategy(mod, env) do
    case Macro.expand(mod, env) do
      mod when is_atom(mod) -> quote do: def(_sk_component_info(:strategy), do: unquote(mod))
      any -> DefinitionError.inject("Invalid strategy: `#{inspect(any)}`", env)
    end
  end
end
