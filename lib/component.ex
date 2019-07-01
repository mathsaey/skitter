# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Reactive Component definition and utilities.

  A Reactive Component is one of the core building blocks of skitter.
  It defines a single data processing step which can be embedded inside a
  reactive workflow.

  This module defines the internal representation of a skitter component as an
  elixir struct (`t:t/0`) along with some utilities to modify and query
  reactive components.
  """

  alias Skitter.Component.Callback
  alias Skitter.{Port, DefinitionError, DSL}

  defstruct name: nil,
            fields: [],
            in_ports: [],
            out_ports: [],
            callbacks: %{}

  @typedoc """
  A component is defined as a collection of _metadata_ and _callbacks_.

  The metadata provides additional information about a component, while the
  various `Skitter.Component.Callback` implement the functionality of a
  component.

  The following metadata is stored:

  | Name          | Description                        | Default |
  | ------------- | ---------------------------------- | ------- |
  | `name`        | The name of the component          | `nil`   |
  | `fields`      | List of the slots of the component | `[]`    |
  | `in_ports`    | List of in ports of the component. | `[]`    |
  | `out_ports`   | List of out ports of the component | `[]`    |

  Note that a valid component must have at least one in port.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          fields: [field()],
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          callbacks: %{optional(callback_name()) => Callback.t()}
        }

  @typedoc """
  Data storage "slot" of a component.

  The state of a component instance is divided into various named slots.
  In skitter, these slots are called _fields_. The fields of a component
  are statically defined and are stored as atoms.
  """
  @type field :: atom()

  @typedoc """
  Callback identifiers.

  The callbacks of a skitter component are named.
  These names are stored as atoms.
  """
  @type callback_name :: atom()

  @doc """
  Call a specific callback of the component.

  Call the callback named `callback_name` of `component` with the arguments
  defined in `t:Skitter.Component.Callback.signature/0`.

  ## Examples

      iex> import Callback, only: [defcallback: 4]
      iex> cb = defcallback([], [], [], do: 10)
      iex> component = %Component{callbacks: %{f: cb}}
      iex> call(component, :f, %{}, [])
      %Callback.Result{state: nil, publish: nil, result: 10}
  """
  @spec call(t(), callback_name(), Callback.state(), [any()]) ::
          Callback.result()
  def call(component = %__MODULE__{}, callback_name, state, arguments) do
    Callback.call(component.callbacks[callback_name], state, arguments)
  end

  @doc """
  Create an initial `t:Callback.state/0` for a given component.

  ## Examples

      iex> create_empty_state(%Component{fields: [:a_field, :another_field]})
      %{a_field: nil, another_field: nil}
      iex> create_empty_state(%Component{fields: []})
      %{}
  """
  @spec create_empty_state(t()) :: Callback.state()
  def create_empty_state(%__MODULE__{fields: fields}) do
    Map.new(fields, &{&1, nil})
  end

  # ------ #
  # Macros #
  # ------ #

  @reuse_directives [:alias, :import, :require]

  @doc """
  DSL to define skitter components.

  A component definition consists of a signature and a body. The first two
  arguments that this macro accepts (`name`, `ports`) make up the signature,
  while the final argument contain the body of the component.

  ## Signature

  The signature of the component declares the externally visible
  meta-information of the component: its name and list of in -and out ports.

  The name of the component is an atom, which is used to register the component.
  By convention, components are named with an elixir alias (e.g. `MyComponent`).
  The name of the component can be omitted, in which case it is not registered.

  The in and out ports of a component are provided as a list of lists of names,
  e.g. `in: [in_port1, in_port2], out: [out_port1, out_port2]`. As a syntactic
  convenience, the `[]` around a port list may be dropped if only a single port
  is declared (e.g.: `out: [foo]` can be written as `out: foo`). Finally, it is
  possible for a component to not define out ports. This can be specified as
  `out: []`, or by dropping the out port sub-list altogether.

  ## Body

  The body of a component may contain any of the following elements:

  | Name                         | Description                              |
  | ---------------------------- | ---------------------------------------  |
  | fields                       | List of the fields of the component      |
  | `import`, `alias`, `require` | Elixir import, alias, require constructs |
  | callback                     | `Skitter.Component.Callback` definition  |

  The fields statement is used to define the various `t:field/0` of the
  component. This statement may be used only once inside the body of the
  component. The statement can be omitted if the component does not have any
  fields.

  `import`, `alias`, and `require` maybe used inside of the component body as
  if they were being used inside of a module. Note that the use of macros inside
  of the component DSL may lead to issues due to the various code
  transformations the DSL performs.

  The remainder of the component body should consist of
  `Skitter.Component.Callback` definitions. Callbacks are defined with a syntax
  similar to an elixir function definition with `def` or `defp` omitted. Thus
  a callback named `react` which accepts two arguments would be defined with
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
  its name.

  ## Examples

  The following component calculates the average of all the values it receives.

      iex> avg = defcomponent Average, in: value, out: current do
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
      iex> state = call(avg, :init, create_empty_state(avg), []).state
      iex> state
      %{count: 0, total: 0}
      iex> res = call(avg, :react, state, [10])
      iex> res.publish
      [current: 10.0]
      iex> res.state
      %{count: 1, total: 10}
  """
  defmacro defcomponent(name \\ nil, ports, do: body) do
    try do
      # Get metadata from header
      name = Macro.expand(name, __CALLER__)
      {in_ports, out_ports} = Port.parse_list(ports, __CALLER__)

      # Parse body
      body = DSL.block_to_list(body)
      {body, fields} = extract_fields(body, __CALLER__)
      {body, imports} = extract_reuse_directives(body)
      callbacks = extract_callbacks(body, imports, fields, out_ports)

      quote do
        %Skitter.Component{
          name: unquote(name),
          fields: unquote(fields),
          in_ports: unquote(in_ports),
          out_ports: unquote(out_ports),
          callbacks: unquote(callbacks)
        }
        |> Skitter.Registry.put_if_named()
      end
    catch
      err -> handle_error(err)
    end
  end

  # Find and remove field declarations in the AST, ensure only one field
  # declaration is present
  defp extract_fields(body, env) do
    Enum.map_reduce(body, [], fn
      {:fields, _, fields}, [] ->
        fields = Enum.map(fields, &DSL.name_to_atom(&1, env))
        {nil, fields}

      {:fields, _, any}, _ ->
        throw {:error, :duplicate_fields, any, env}

      any, acc ->
        {any, acc}
    end)
  end

  defp extract_reuse_directives(body) do
    Enum.map_reduce(body, [], fn
      node = {call, _, _}, acc when call in @reuse_directives ->
        {nil, [node | acc]}

      any, acc ->
        {any, acc}
    end)
  end

  # Fetch every top level statement of the body and turn it into a map of
  # callbacks. Ensure the creation of the map is in AST form.
  defp extract_callbacks(statements, imports, fields, out) do
    callbacks =
      statements
      |> Enum.reject(&is_nil(&1))
      |> Enum.reduce([], &[transform_callback(&1, imports, fields, out) | &2])
      |> Enum.reverse()

    {:%{}, [], callbacks}
  end

  # Transform a `name args do ... end` ast node into a defcallback call.
  defp transform_callback({name, _, args}, imports, fields, out) do
    {args, [body]} = Enum.split(args, -1)

    body =
      quote do
        unquote(imports)
        import unquote(__MODULE__.Callback), only: [defcallback: 4]
        defcallback(unquote(fields), unquote(out), unquote(args), unquote(body))
      end

    {name, body}
  end

  defp handle_error({:error, :invalid_syntax, statement, env}) do
    DefinitionError.inject("Invalid syntax: `#{statement}`", env)
  end

  defp handle_error({:error, :invalid_port_list, any, env}) do
    DefinitionError.inject("Invalid port list: `#{inspect(any)}`", env)
  end

  defp handle_error({:error, :duplicate_fields, fields, env}) do
    DefinitionError.inject(
      "Only one fields declaration is allowed: `#{inspect(fields)}`",
      env
    )
  end
end

defimpl Inspect, for: Skitter.Component do
  import Inspect.Algebra
  alias Skitter.Component

  def inspect(comp, opts) do
    open = group(concat(["#Component", name(comp, opts), "<"]))
    close = ">"

    container_doc(open, Map.to_list(comp), close, opts, &doc/2)
  end

  defp name(%Component{name: nil}, _), do: empty()

  defp name(%Component{name: name}, opts) do
    concat(["[", to_doc(name, opts), "]"])
  end

  def doc({atm, _}, _) when atm in [:__struct__, :name], do: empty()

  def doc({e, l}, o) do
    desc =
      case e do
        :in_ports -> "in:"
        :out_ports -> "out:"
        :fields -> "fields:"
        :callbacks -> "callbacks:"
      end

    group(glue(desc, to_doc(l, o)))
  end
end
