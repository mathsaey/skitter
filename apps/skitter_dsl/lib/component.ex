# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component do
  @moduledoc """
  Component definition DSL. See `defcomponent/3`.
  """
  alias Skitter.DSL.{AST, DefinitionError, Callback}

  @doc """
  DSL to define `t:Skitter.Component.t/0`.

  This macro offers a DSL to create a Skitter component which can be embedded inside a Skitter
  workflow or used as component strategies.

  A component definition consists of a signature and a body. The first two arguments that this
  macro accepts (`name`, `ports`) make up the signature, while the final argument contain the body
  of the component.

  ## Signature

  The signature of the component declares the externally visible meta-information of the
  component: its name and list of in -and out ports.

  The name of the component is an atom, which is used to register the component.  By convention,
  components are named with an elixir alias (e.g. `MyComponent`).  The name of the component can
  be omitted, in which case it is not registered.

  The in and out ports of a component are provided as a list of lists of names, e.g. `in:
  [in_port1, in_port2], out: [out_port1, out_port2]`. As a syntactic convenience, the `[]` around
  a port list may be dropped if only a single port is declared (e.g.: `out: [foo]` can be written
  as `out: foo`). Finally, it is possible for a component to not define out ports. This can be
  specified as `out: []`, or by dropping the out port sub-list altogether.

  ## Body

  The body of a component may contain any of the following elements:

  | Name                         | Description                              |
  | ---------------------------- | ---------------------------------------  |
  | fields                       | List of the fields of the component      |
  | strategy                     | Specify the strategy of the component    |
  | `import`, `alias`, `require` | Elixir import, alias, require constructs |
  | callback                     | `Skitter.Component.Callback` definition  |

  The fields statement is used to define the various `t:Component.field/0` of the component. This
  statement may be used only once inside the body of the component. The statement can be omitted
  if the component does not have any fields.

  The strategy specifies the name of the `t:Skitter.Strategy.t/0` of the component.

  `import`, `alias`, and `require` maybe used inside of the component body as if they were being
  used inside of a module. Note that the use of macros inside of the component DSL may lead to
  issues due to the various code transformations the DSL performs.

  The remainder of the component body should consist of `Skitter.Component.Callback` definitions.
  Callbacks are defined with a syntax similar to an elixir function definition with `def` or
  `defp` omitted. Thus a callback named `react` which accepts two arguments would be defined with
  the following syntax:

  ```
  react arg1, arg2 do
  <body>
  end
  ```

  Internally, callback declarations are transformed into a call to the
  `Skitter.Component.Callback.defcallback/4` macro. Please refer to its
  documentation to learn about the constructs that may be used in the body of a
  callback. Note that the `fields`, `out_ports`, and `args` arguments of the
  call to `defcallback/4` will be provided automatically. As an example, the
  example above would be translated to the following call:

  ```
  defcallback(<component fields>, <component out ports>, [arg1, arg2], body)
  ```

  The generated callback will be stored in the component callbacks field under
  its name (e.g. `:react`).

  ## Examples

  The following component calculates the average of all the values it receives.

      iex> avg = defcomponent Average, in: value, out: current do
      ...>    strategy TestStrategy
      ...>    fields total, count
      ...>
      ...>    init do
      ...>      total <~ 0
      ...>      count <~ 0
      ...>    end
      ...>
      ...>    react value do
      ...>      count <~ count + 1
      ...>      total <~ total + value
      ...>
      ...>      total / count ~> current
      ...>    end
      ...>  end
      iex> avg.name
      Average
      iex> avg.fields
      [:total, :count]
      iex> avg.in_ports
      [:value]
      iex> avg.out_ports
      [:current]
      iex> Component.call(avg, :init, Component.create_empty_state(avg), []).state
      %{count: 0, total: 0}
      iex> res = Component.call(avg, :react, %{count: 0, total: 0}, [10])
      iex> res.publish
      [current: 10.0]
      iex> res.state
      %{count: 1, total: 10}
  """
  @doc section: :dsl
  defmacro defcomponent(name \\ nil, ports, do: body) do
    try do
      {in_ports, out_ports} = AST.parse_port_list(ports, __CALLER__)

      body = AST.block_to_list(body)
      {body, imports} = AST.extract_calls(body, [:alias, :import, :require])
      {body, fields} = AST.extract_calls(body, [:fields])
      {body, strategy} = AST.extract_calls(body, [:strategy])

      fields = verify_fields(fields, __CALLER__)
      strategy = transform_strategy(strategy, imports, __CALLER__)
      callbacks = Callback.extract_callbacks(body, imports, fields, out_ports)

      quote do
        require Skitter.DSL.Named

        %Skitter.Component{
          name: unquote(name),
          fields: unquote(fields),
          in_ports: unquote(in_ports),
          out_ports: unquote(out_ports),
          callbacks: unquote(callbacks),
          strategy: unquote(__MODULE__).expand_strategy(unquote(strategy))
        }
        |> unquote(__MODULE__).verify_strategy()
        |> Skitter.Strategy.define()
        |> Skitter.DSL.Named.store(unquote(name))
      end
    catch
      err -> handle_error(err)
    end
  end

  # Parse field names, ensure only one field declaration is present
  defp verify_fields([], _), do: []

  defp verify_fields([{:fields, _, fields}], env) do
    Enum.map(fields, &AST.name_to_atom(&1, env))
  end

  defp verify_fields([_fields, dup | _], env) do
    throw {:error, :duplicate_fields, dup, env}
  end

  # Ensure no duplicate strategy is present, add needed imports
  defp transform_strategy([], _, env) do
    throw {:error, :missing_strategy, env}
  end

  defp transform_strategy([_, dup | _], _, env) do
    throw {:error, :duplicate_strategy, dup, env}
  end

  defp transform_strategy([{:strategy, _, [strategy]}], imports, _) do
    quote do
      unquote(imports)
      unquote(strategy)
    end
  end

  def expand_strategy(s = %Skitter.Strategy{}), do: s
  def expand_strategy(name) when is_atom(name), do: Skitter.DSL.Named.load(name)

  def expand_strategy(any) do
    raise DefinitionError, "`#{inspect(any)}` is not a valid component strategy"
  end

  def verify_strategy(c = %Skitter.Component{strategy: strategy}) do
    if Skitter.Strategy.complete?(strategy) do
      c
    else
      raise DefinitionError, "`#{inspect(strategy)}` is not complete"
    end
  end

  defp handle_error({:error, :invalid_syntax, statement, env}) do
    DefinitionError.inject("Invalid syntax: `#{Macro.to_string(statement)}`", env)
  end

  defp handle_error({:error, :invalid_port_list, any, env}) do
    DefinitionError.inject("Invalid port list: `#{Macro.to_string(any)}`", env)
  end

  defp handle_error({:error, :duplicate_fields, fields, env}) do
    DefinitionError.inject(
      "Only one fields declaration is allowed: `#{Macro.to_string(fields)}`",
      env
    )
  end

  defp handle_error({:error, :duplicate_strategy, strategy, env}) do
    DefinitionError.inject(
      "Only one strategy declaration is allowed: `#{Macro.to_string(strategy)}`",
      env
    )
  end

  defp handle_error({:error, :missing_strategy, env}) do
    DefinitionError.inject("Missing strategy", env)
  end
end
