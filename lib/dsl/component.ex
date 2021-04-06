# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

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
  alias Skitter.{Component.Callback.Info, DefinitionError, Port, Strategy, Strategy.Context}

  @typedoc """
  Component information before compilation.

  This struct contains the information tracked by the component DSL before it is compiled. This
  information is passed to the `c:Skitter.Strategy.define/2` hook, which can use this information to
  verify the correctness of the component definition and inject additional code. Any changes made
  to this struct are reflected in the generated module.

  The following information is tracked:

  - `in`: the list of in ports
  - `out`: the list of out ports
  - `strategy`: the strategy of the component
  - `inject`: additional code to add to the component before it is compiled.
  """
  @type info :: %__MODULE__{
          in: [Port.t()],
          out: [Port.t()],
          strategy: Strategy.t(),
          inject: [Macro.t()]
        }

  defstruct [:in, :out, :strategy, :callbacks, :inject]

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

  If a component has no `in`, or `out` ports, they can be omitted from the component's header.
  Furthermore, if the component only has a single `in` or `out` port, the list notation can be
  omitted:

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

  ### `c:Skitter.Strategy.define/2`

  The strategy of a component may modify a component before it is defined. This is done through
  the `c:Skitter.Strategy.define/2` hook, which is called by `defcomponent/3` _before_ the
  generated module is compiled. This hook accepts a `t:info/0` argument, which contains
  information about the component. Any changes made to this struct are propagated to the generated
  module. For instance:

      iex> defstrategy ChangePorts, extends: Dummy do
      ...>   defhook define(info) do
      ...>     %{info | in: [:new_port]}
      ...>   end
      ...> end
      iex> defcomponent Example, in: some_port, strategy: ChangePorts do
      ...> end
      iex> Component.in_ports(Example)
      [:new_port]

  Besides this, a `t:info/0` struct has an `:inject` field, which defaults to an empty list. Any
  code added to this list is added to the module before it is compiled.

      iex> defstrategy AddFunction, extends: Dummy do
      ...>   defhook define(info) do
      ...>     %{info | inject: [quote(do: def(hello, do: "Hello, world!"))]}
      ...>   end
      ...> end
      iex> defcomponent Example, strategy: AddFunction do
      ...> end
      iex> Example.hello()
      "Hello, world!"

  It is generally not needed to directly modify the `t:info/0` struct. Instead, this module
  provides multiple "definition helpers" which accept a `t:info/0` struct to modify.

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
        import unquote(__MODULE__), only: [fields: 1, defcb: 2]

        @before_compile {unquote(__MODULE__), :strategy_hook}
        @before_compile {unquote(__MODULE__), :generate_callbacks}

        Module.register_attribute(__MODULE__, :_sk_callbacks, accumulate: true)

        @_sk_strategy unquote(strategy)
        @_sk_in_ports unquote(in_)
        @_sk_out_ports unquote(out)

        unquote(fields_ast)
        unquote(body)
      end
    end
  end

  defp read_strategy(nil, env), do: DefinitionError.inject("Missing strategy", env)

  defp read_strategy(mod, env) do
    case Macro.expand(mod, env) do
      mod when is_atom(mod) -> mod
      any -> DefinitionError.inject("Invalid strategy: `#{inspect(any)}`", env)
    end
  end

  @doc false
  # Call the strategy define/2 hook and extract the results
  defmacro strategy_hook(env) do
    strategy = Module.get_attribute(env.module, :_sk_strategy)

    hook_result =
      strategy.define(
        %Context{strategy: strategy, component: env.module},
        %__MODULE__{
          in: Module.get_attribute(env.module, :_sk_in_ports),
          out: Module.get_attribute(env.module, :_sk_out_ports),
          strategy: strategy,
          inject: []
        }
      )

    quote do
      @_sk_in_ports unquote(hook_result.in)
      @_sk_out_ports unquote(hook_result.out)
      @_sk_strategy unquote(hook_result.strategy)

      import unquote(__MODULE__),
        only: [
          default_cb: 3,
          require_cb: 4,
          arity: 1,
          in_ports: 1,
          out_ports: 1,
          strategy: 1,
          modify_in_ports: 2,
          modify_out_ports: 2,
          modify_strategy: 2
        ]

      unquote_splicing(hook_result.inject)
    end
  end

  @doc false
  # generate component behaviour callbacks
  defmacro generate_callbacks(env) do
    names = env.module |> get_info_before_compile() |> Map.keys()
    metadata = env.module |> get_info_before_compile() |> Macro.escape()

    quote bind_quoted: [names: names, metadata: metadata] do
      @impl true
      def _sk_component_info(:strategy), do: @_sk_strategy
      def _sk_component_info(:in_ports), do: @_sk_in_ports
      def _sk_component_info(:out_ports), do: @_sk_out_ports

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

  # --------- #
  # Callbacks #
  # --------- #

  # Private / Hidden Helpers
  # ------------------------

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

  # -------------- #
  # Before Compile #
  # -------------- #

  @doc """
  Get the arity of a component before it is defined.
  """
  @doc section: :pre_compile
  @spec arity(info()) :: arity()
  def arity(%__MODULE__{in: ports}), do: length(ports)

  @doc """
  Get the in ports of a component before it is defined.
  """
  @doc section: :pre_compile
  @spec in_ports(info()) :: [Port.t()]
  def in_ports(%__MODULE__{in: ports}), do: ports

  @doc """
  Get the out ports of a component before it is defined.
  """
  @doc section: :pre_compile
  @spec out_ports(info()) :: [Port.t()]
  def out_ports(%__MODULE__{out: ports}), do: ports

  @doc """
  Get the strategy of a component before it is defined.
  """
  @doc section: :pre_compile
  @spec strategy(info()) :: Strategy.t()
  def strategy(%__MODULE__{strategy: strategy}), do: strategy

  @doc """
  Update the in ports of a component before it is defined.

  This function can be called with a new value for the in ports, or with a function. If a value
  is provided, it will be used as the new value for in_ports. When a function is provided, it
  will be called with the current in ports. The return value of the function will be used as the
  new value for in ports.

  ## Examples

      iex> defstrategy ModifyInPorts, extends: Dummy do
      ...>   defhook define(component), do: modify_in_ports(component, [:bar])
      ...> end
      iex> defcomponent Example, in: foo, strategy: ModifyInPorts do
      ...> end
      iex> Component.in_ports(Example)
      [:bar]
      iex> defstrategy ModifyInPorts, extends: Dummy do
      ...>   defhook define(component), do: modify_in_ports(component, &[:foo | &1])
      ...> end
      iex> defcomponent Example, in: bar, strategy: ModifyInPorts do
      ...> end
      iex> Component.in_ports(Example)
      [:foo, :bar]
  """
  @doc section: :pre_compile
  @spec modify_in_ports(info(), [Port.t()] | ([Port.t()] -> [Port.t()])) :: info()
  def modify_in_ports(info, func) when is_function(func, 1) do
    modify_in_ports(info, func.(in_ports(info)))
  end

  def modify_in_ports(info, ports), do: %{info | in: ports}

  @doc """
  Update the out ports of a component before it is defined.

  This function can be called with a new value for the out ports, or with a function. If a value
  is provided, it will be used as the new value for out_ports. When a function is provided, it
  will be called with the current out ports. The return value of the function will be used as the
  new value for out ports.

  ## Examples

      iex> defstrategy ModifyOutPorts, extends: Dummy do
      ...>   defhook define(component), do: modify_out_ports(component, [:bar])
      ...> end
      iex> defcomponent Example, out: foo, strategy: ModifyOutPorts do
      ...> end
      iex> Component.out_ports(Example)
      [:bar]
      iex> defstrategy ModifyOutPorts, extends: Dummy do
      ...>   defhook define(component), do: modify_out_ports(component, &[:foo | &1])
      ...> end
      iex> defcomponent Example, out: bar, strategy: ModifyOutPorts do
      ...> end
      iex> Component.out_ports(Example)
      [:foo, :bar]
  """
  @doc section: :pre_compile
  @spec modify_out_ports(info(), [Port.t()] | ([Port.t()] -> [Port.t()])) :: info()
  def modify_out_ports(info, func) when is_function(func, 1) do
    modify_out_ports(info, func.(out_ports(info)))
  end

  def modify_out_ports(info, ports), do: %{info | out: ports}

  @doc """
  Update the strategy ports of a component before it is defined.

  Note that the `c:Skitter.Strategy.define/2` hook of the new strategy will not be called.

  ## Examples

      iex> defstrategy ModifyStrategy, extends: Dummy do
      ...>   defhook define(component) do
      ...>     modify_strategy(component, SomeOtherStrategy)
      ...>   end
      ...> end
      iex> defcomponent Example, strategy: ModifyStrategy do
      ...> end
      iex> Component.strategy(Example)
      SomeOtherStrategy
  """
  @doc section: :pre_compile
  @spec modify_strategy(info(), Strategy.t()) :: info()
  def modify_strategy(info, strategy) when is_atom(strategy), do: %{info | strategy: strategy}

  @doc """
  Add a callback if it does not exist yet.

  This macro defines a callback using `defcb/2`, if a callback with the same signature does not
  exist (i.e. if there is no callback with the same name and arity present in the module where
  this macro is used).

  Note that this macro is not imported by `defcomponent/3`.

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
  Add `default_cb/2` to `t:info/0`.

  This add a call to `default_cb/2` to the provided `info` struct. This macro can be used to add a
  default callback to a component inside `c:Skitter.Strategy.define/2`.

  ## Examples

      iex> defstrategy Default, extends: Dummy do
      ...>   defhook define(component) do
      ...>     default_cb(component, init()) do
      ...>       :default
      ...>     end
      ...>   end
      ...> end
      iex> defcomponent Example, strategy: Default do
      ...> end
      iex> Component.call(Example, :init, []).result
      :default
  """
  @doc section: :pre_compile
  defmacro default_cb(info, signature, do: body) do
    macro =
      quote(do: Skitter.DSL.Component.default_cb(unquote(signature), do: unquote(body)))
      |> Macro.escape()

    quote do
      Map.update!(unquote(info), :inject, &(&1 ++ [unquote(macro)]))
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

  @doc """
  Add `require_cb/3` to `t:info/0`.

  This add a call to `require_cb/3` to the provided `info` struct. This macro can be used to
  ensure a callback is defined inside `c:Skitter.Strategy.define/2`.

  ## Examples

      iex> defstrategy Require, extends: Dummy do
      ...>   defhook define(component) do
      ...>     require_cb(component, :react, arity(component), publish?: false)
      ...>   end
      ...> end
      iex> defcomponent Example, out: port, strategy: Require do
      ...>   defcb react(), do: :foo ~> port
      ...> end
      ** (Skitter.DefinitionError) Incorrect publish for callback react, expected [], got [:port]
  """
  @doc section: :pre_compile
  @spec require_cb(info(), atom(), arity(), [{atom(), any()}]) :: info()
  def require_cb(info, name, arity, properties) do
    quoted =
      quote do
        Skitter.DSL.Component.require_cb(unquote(name), unquote(arity), unquote(properties))
      end

    Map.update!(info, :inject, &(&1 ++ [quoted]))
  end
end
