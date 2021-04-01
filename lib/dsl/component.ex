# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel
# me

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component do
  @moduledoc """
  Callback and Component definition DSL.

  This module offers macros to define component modules and callbacks. To define a component, use
  `defcomponent/3`. Inside the component body, `defcb/2` can be used to define callbacks. Inside
  the body of `defcb/2`, `sigil_f/2`, `<~/2` and `~>/2` can be used to respectively read the
  state, update the state or publish data.
  """
  alias Skitter.DSL.AST
  alias Skitter.DefinitionError
  alias Skitter.Component.Callback.Info

  # --------- #
  # Component #
  # --------- #

  @doc """
  Define the fields of the component's state.

  This macro defines the various fields that make up the state of a component. It is used
  similarly to `defstruct/1`. You should only use this macro once inside the body of a component.
  Note that an empty state will automatically be generated if this macro is not used.

  When multiple `fields` declarations are present, a `Skitter.DefinitionError` will be raised.

  ## Internal representation as a struct

  Currently, this macro is syntactic sugar for directly calling `defstruct/1`. Programmers should
  not rely on this property however, as it may change in the future. The use of `fields/1` is
  preferred as it decouples the definition of the layout of a state from its internal
  representation as an elixir struct.

  ## Examples

  ```
  defcomponent FieldsExample, strategy: Dummy do
    fields foo: 42
  end
  ```

      iex> Component.create_empty_state(FieldsExample)
      %FieldsExample{foo: 42}

  ```
  defcomponent NoFields, strategy: Dummy do
  end
  ```

      iex> Component.create_empty_state(NoFields)
      %NoFields{}
  """
  defmacro fields(lst) do
    quote do
      defstruct unquote(lst)
    end
  end

  @doc """
  Define a component module.

  This macro is used to define a component module. Using this macro, a component can be defined
  similar to a normal module. The macro will enable the use of `defcb/2`, ensure a struct is
  defined to represent the component's state and provide implementations for
  `c:Skitter.Component._sk_component_info/1`, `c:Skitter.Component._sk_callback_list/0` and
  `c:Skitter.Component._sk_callback_info/2`.

  ## Component strategy and ports

  The component Strategy and its in -and out ports can be defined in the header of the component
  declaration as follows:

      iex> defcomponent SignatureExample, in: [a, b, c], out: [y, z], strategy: Dummy do
      ...> end
      iex> Component.strategy(SignatureExample)
      Dummy
      iex> Component.in_ports(SignatureExample)
      [:a, :b, :c]
      iex> Component.out_ports(SignatureExample)
      [:y, :z]

  If a component has no `in`, or `out` ports, it can be omitted from the component's header.
  Furthermore, if only a single `in` or `out` port, the list notation can be omitted:

      iex> defcomponent PortExample, in: a, strategy: Dummy do
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
  defcomponent Average, in: value, out: current, strategy: Dummy do
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
      Dummy

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
        @behaviour Skitter.Component

        @before_compile {unquote(__MODULE__), :generate_callback_info}
        Module.register_attribute(__MODULE__, :_sk_callbacks, accumulate: true)

        import unquote(__MODULE__), only: [fields: 1, defcb: 2]

        @impl true
        def _sk_component_info(:in_ports), do: unquote(in_)
        def _sk_component_info(:out_ports), do: unquote(out)
        unquote(strategy)

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

  # --------- #
  # Callbacks #
  # --------- #

  # Private / Hidden Helpers
  # ------------------------

  @doc false
  # generate _sk_callback_list and _sk_callback_info
  defmacro generate_callback_info(env) do
    names = env.module |> get_info_before_compile() |> Map.keys()
    metadata = env.module |> get_info_before_compile() |> Macro.escape()

    quote bind_quoted: [names: names, metadata: metadata] do
      @impl true
      def _sk_callback_list, do: unquote(names)

      # Prevent a warning if no callbacks are defined
      @impl true
      def _sk_callback_info(nil, 0), do: %Skitter.Component.Callback.Info{}

      for {{name, arity}, info} <- metadata do
        def _sk_callback_info(unquote(name), unquote(arity)), do: unquote(Macro.escape(info))
      end
    end
  end

  @doc false
  # Gets the callback info before generate_callback_info/1 is called.
  def get_info_before_compile(module) do
    module
    |> Module.get_attribute(:_sk_callbacks)
    |> Enum.reduce(%{}, fn {{name, arity}, info}, map ->
      Map.update(map, {name, arity}, info, fn s = %Info{} ->
        %{
          s
          | read: Enum.uniq(s.read ++ info.read),
            write: Enum.uniq(s.write ++ info.write),
            publish: Enum.uniq(s.publish ++ info.publish)
        }
      end)
    end)
  end

  # Extract calls to a certain operator from the AST
  defp extract(body, verify) do
    body
    |> Macro.prewalk(MapSet.new(), fn
      node, acc -> if el = verify.(node), do: {node, MapSet.put(acc, el)}, else: {node, acc}
    end)
    |> elem(1)
    |> Enum.to_list()
  end

  # State
  # -----

  @doc """
  Read the state of a field.

  This macro reads the current value of `field` in the state passed to
  `Skitter.Component.call/4`.

  This macro should only be used inside the body of `defcb/2`.

  ## Examples

  ```
  defcomponent ReadExample, strategy: Dummy do
    fields [:field]
    defcb read(), do: ~f{field}
  end
  ```

      iex> Component.call(ReadExample, :read, %ReadExample{field: 5}, []).result
      5

      iex> Component.call(ReadExample, :read, %ReadExample{field: :foo}, []).result
      :foo
  """
  defmacro sigil_f({:<<>>, _, [str]}, _), do: str |> String.to_existing_atom() |> state_var()

  @doc """
  Update the state of a field.

  This macro should only be used inside the body of `defcb/2`. It updates the value of
  `field` to `value` and returns `value` as its result. Note that `field` needs to exist inside
  `state`. If it does not exist, a `KeyError` will be raised.

  ## Examples

  ```
  defcomponent WriteExample, strategy: Dummy do
    fields [:field]
    defcb write(), do: field <~ :bar
  end
  ```
      iex> Component.call(WriteExample, :write, %WriteExample{field: :foo}, []).state.field
      :bar

  ```
  defcomponent WrongWriteExample, strategy: Dummy do
    fields [:field]
    defcb write(), do: doesnotexist <~ :bar
  end
  ```
      iex> Component.call(WrongWriteExample, :write, %WriteExample{field: :foo}, [])
      ** (KeyError) key :doesnotexist not found
  """
  defmacro {field, _, _} <~ value when is_atom(field) do
    quote do
      unquote(state_var(field)) = unquote(value)
    end
  end

  @doc false
  def state_var(atom) do
    context = __MODULE__.State
    quote(do: var!(unquote(Macro.var(atom, context)), unquote(context)))
  end

  defp state_init(fields, state_arg) do
    for atom <- fields do
      quote do
        unquote(state_var(atom)) = Map.fetch!(unquote(state_arg), unquote(atom))
      end
    end
  end

  defp state_return(fields, state_arg) do
    writes = for atom <- fields, do: {atom, state_var(atom)}

    quote do
      %{unquote(state_arg) | unquote_splicing(writes)}
    end
  end

  defp get_reads(body) do
    extract(body, fn
      {:sigil_f, _env, [{:<<>>, _, [field]}, _]} -> String.to_existing_atom(field)
      _ -> false
    end)
  end

  @doc false
  def get_writes(body) do
    extract(body, fn
      {:<~, _env, [{name, _, _}, _]} -> name
      _ -> false
    end)
  end

  # Publish
  # -------

  @doc """
  Publish `value` to `port`

  This macro is used to specify `value` should be published on `port`. It should only be used
  inside the body of `defcb/2`. If a previous value was specified for `port`, it is overridden.

  ## Examples

  ```
  defcomponent PublishExample, strategy: Dummy do
    defcb publish(value) do
      value ~> some_port
      :foo ~> some_other_port
    end
  end
  ```

      iex> Component.call(PublishExample, :publish, [:bar]).publish
      [some_other_port: :foo, some_port: :bar]
  """
  defmacro value ~> {port, _, _} when is_atom(port) do
    quote do
      value = unquote(value)
      unquote(publish_var()) = Keyword.put(unquote(publish_var()), unquote(port), value)
      value
    end
  end

  @doc false
  def publish_var, do: quote(do: var!(publish, unquote(__MODULE__)))

  defp publish_init(_), do: quote(do: unquote(publish_var()) = [])
  defp publish_return(_), do: quote(do: unquote(publish_var()))

  @doc false
  def get_published(body) do
    extract(body, fn
      {:~>, _env, [_, {name, _, _}]} -> name
      _ -> false
    end)
  end

  # defcallback
  # -----------

  @doc """
  Define a callback.

  This macro is used to define a callback function. Using this macro, a callback can be defined
  similar to a regular procedure. Inside the body of the procedure, `~>/2`, `<~/2` and `sigil_f/2`
  can be used to access the state and to publish output. The macro ensures:

  - The function returns a `t:Skitter.Component.result/0` with the correct state (as updated by
  `<~/2`), publish (as updated by `~>/2`) and result (which contains the value of the last
  expression in `body`).

  - `c:Skitter.Component._sk_callback_info/2` and `c:Skitter.Callback._sk_callback_list/0` of the
  component module contains the required information about the defined callback.

  Note that, under the hood, `defcb/2` generates a regular elixir function. Therefore, pattern
  matching may still be used in the argument list of the callback. Attributes such as `@doc` may
  also be used as usual.

  ## Examples

  ```
  defcomponent CbExample, strategy: Dummy do
    defcb simple(), do: nil
    defcb arguments(arg1, arg2), do: arg1 + arg2
    defcb state(), do: counter <~ (~f{counter} + 1)
    defcb publish(), do: ~D[1991-12-08] ~> out_port
  end
  ```

      iex> Component.callback_list(CbExample)
      [arguments: 2, publish: 0, simple: 0, state: 0]

      iex> Component.callback_info(CbExample, :simple, 0)
      %Info{read: [], write: [], publish: []}

      iex> Component.callback_info(CbExample, :arguments, 2)
      %Info{read: [], write: [], publish: []}

      iex> Component.callback_info(CbExample, :state, 0)
      %Info{read: [:counter], write: [:counter], publish: []}

      iex> Component.callback_info(CbExample, :publish, 0)
      %Info{read: [], write: [], publish: [:out_port]}

      iex> Component.call(CbExample, :simple, %{}, [])
      %Result{result: nil, publish: [], state: %{}}

      iex> Component.call(CbExample, :arguments, %{}, [10, 20])
      %Result{result: 30, publish: [], state: %{}}

      iex> Component.call(CbExample, :state, %{counter: 10, other: :foo}, [])
      %Result{result: 11, publish: [], state: %{counter: 11, other: :foo}}

      iex> Component.call(CbExample, :publish, %{}, [])
      %Result{result: ~D[1991-12-08], publish: [out_port: ~D[1991-12-08]], state: %{}}
  """
  defmacro defcb(signature, do: body) do
    body = __MODULE__.ControlFlowOperators.rewrite_special_forms(body)
    {name, args} = Macro.decompose_call(signature)
    published = get_published(body)
    writes = get_writes(body)
    reads = get_reads(body)

    state_var = Macro.var(:state, __MODULE__)
    arity = length(args)

    info = %Info{read: reads, write: writes, publish: published} |> Macro.escape()

    quote do
      @_sk_callbacks {{unquote(name), unquote(arity)}, unquote(info)}
      def unquote(name)(unquote(state_var), unquote_splicing(args)) do
        import unquote(__MODULE__), only: [sigil_f: 2, ~>: 2, <~: 2]
        use unquote(__MODULE__.ControlFlowOperators)

        unquote(state_init(reads, state_var))
        unquote(publish_init(published))

        result = unquote(body)

        %Skitter.Component.Callback.Result{
          result: result,
          state: unquote(state_return(writes, state_var)),
          publish: unquote(publish_return(body))
        }
      end
    end
  end

  # Utilities
  # ---------

  @doc """
  Add a callback if it does not exist yet.

  This macro defines a callback using `defcb/2`, if a callback with the same signature does not
  exist (i.e. if there is no callback with the same name and arity present in the module where
  this macro is used).

  Note that this macro is not imported by default by `defcomponent/3`.

  ## Examples

      iex> defcomponent DefaultExample, strategy: Dummy do
      ...>   defcb foo(), do: :foo
      ...>
      ...>   Skitter.DSL.Component.default_cb foo(), do: :default
      ...>   Skitter.DSL.Component.default_cb bar(), do: :default
      ...> end
      iex> Component.callback_list(DefaultExample)
      [bar: 0, foo: 0]
      iex> Component.call(DefaultExample, :foo, %{}, [])
      %Result{result: :foo, publish: [], state: %{}}
      iex> Component.call(DefaultExample, :bar, %{}, [])
      %Result{result: :default, publish: [], state: %{}}
  """
  defmacro default_cb(signature, do: body) do
    {name, args} = Macro.decompose_call(signature)
    arity = length(args)

    quote do
      import Skitter.DSL.Component, only: [get_info_before_compile: 1, defcb: 2]

      unless Map.has_key?(get_info_before_compile(__MODULE__), {unquote(name), unquote(arity)}) do
        defcb(unquote(signature), do: unquote(body))
      end
    end
  end

  @doc """
  Ensure a callback exists and verify its properties.

  This macro injects code that ensures a callback with `name` and `arity` exists. If the callback
  does not exist, a `Skitter.DefinitionError` is raised. If the callback exists, its properties
  are verified using `Skitter.Component.verify!/3`.

  ## Examples

      The following example will compile without issues:

      iex> defcomponent RequireExample, strategy: Dummy do
      ...>   defcb foo(), do: :foo ~> out
      ...>
      ...>   Skitter.DSL.Component.require_cb(:foo, 0)
      ...> end

      The following examples will not compile:

      iex> defcomponent MissingRequireExample, strategy: Dummy do
      ...>   Skitter.DSL.Component.require_cb(:foo, 0)
      ...> end
      ** (Skitter.DefinitionError) Missing required callback foo with arity 0

      iex> defcomponent VerifyRequireExample, strategy: Dummy do
      ...>   defcb foo(), do: :foo ~> out
      ...>
      ...>   Skitter.DSL.Component.require_cb(:foo, 0, publish?: false)
      ...> end
      ** (Skitter.DefinitionError) Incorrect publish for callback foo, expected [], got [:out]

  """
  defmacro require_cb(name, arity, properties \\ []) do
    quote do
      __MODULE__
      |> Skitter.DSL.Component.get_info_before_compile()
      |> Map.get({unquote(name), unquote(arity)})
      |> case do
        nil ->
          raise Skitter.DefinitionError,
                "Missing required callback #{unquote(name)} with arity #{unquote(arity)}"

        info ->
          Skitter.Component.verify!(info, unquote(name), unquote(properties))
      end
    end
  end
end
