# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component do
  @moduledoc """
  Callback and Component definition DSL.

  This module offers macros to define component modules and callbacks. To define a component, use
  `defcomponent/3`. Inside the component body, `defcb/2` can be used to define callbacks. Inside
  the body of `defcb/2`, `sigil_f/2`, `<~/2`, `~>/2` and `~>>/2` can be used to respectively read
  the state, update the state or publish data.
  """
  alias Skitter.DSL.AST
  alias Skitter.{Component.Callback.Info, DefinitionError}

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
  defcomponent FieldsExample do
    fields foo: 42
  end
  ```

      iex> Component.create_empty_state(FieldsExample)
      %FieldsExample{foo: 42}

  ```
  defcomponent NoFields do
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

      iex> defcomponent SignatureExample, in: [a, b, c], out: [y, z], strategy: SomeStrategy do
      ...> end
      iex> Component.strategy(SignatureExample)
      SomeStrategy
      iex> Component.in_ports(SignatureExample)
      [:a, :b, :c]
      iex> Component.out_ports(SignatureExample)
      [:y, :z]

  If a component has no `in`, or `out` ports, they can be omitted from the component's header.
  Furthermore, if the component only has a single `in` or `out` port, the list notation can be
  omitted:

      iex> defcomponent PortExample, in: a do
      ...> end
      iex> Component.in_ports(PortExample)
      [:a]
      iex> Component.out_ports(PortExample)
      []

  The strategy may be omitted. In this case, a strategy _must_ be provided when the defined
  component is embedded inside a workflow. If this is not done, an error will be raised when the
  workflow is deployed.

  ## Examples

  ```
  defcomponent Average, in: value, out: current do
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
      nil

      iex> Component.call(Average, :react, [10])
      %Result{result: 10.0, publish: [current: [10.0]], state: %Average{count: 1, total: 10}}

      iex> Component.call(Average, :react, %Average{count: 1, total: 10}, [10])
      %Result{result: 10.0, publish: [current: [10.0]], state: %Average{count: 2, total: 20}}
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

  defp read_strategy(mod, env) do
    case Macro.expand(mod, env) do
      mod when is_atom(mod) -> mod
      any -> DefinitionError.inject("Invalid strategy: `#{inspect(any)}`", env)
    end
  end

  @doc false
  # generate component behaviour callbacks
  defmacro generate_callbacks(env) do
    names = env.module |> _info_before_compile() |> Map.keys()
    metadata = env.module |> _info_before_compile() |> Macro.escape()

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
  def _info_before_compile(module) do
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
  defcomponent ReadExample do
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
  defcomponent WriteExample do
    fields [:field]
    defcb write(), do: field <~ :bar
  end
  ```
      iex> Component.call(WriteExample, :write, %WriteExample{field: :foo}, []).state.field
      :bar

  ```
  defcomponent WrongWriteExample do
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

  This macro is used to specify `value` should be published on `port`. This means that `value`
  will be sent to any components downstream of the current component. This macro should only be
  used inside the body of `defcb/2`. If a previous value was specified for `port`, it is
  overridden.

  ## Examples

  ```
  defcomponent SinglePublishExample do
    defcb publish(value) do
      value ~> some_port
      :foo ~> some_other_port
    end
  end
  ```

      iex> Component.call(SinglePublishExample, :publish, [:bar]).publish
      [some_other_port: [:foo], some_port: [:bar]]
  """
  defmacro value ~> {port, _, _} when is_atom(port) do
    quote do
      value = unquote(value)
      unquote(publish_var()) = Keyword.put(unquote(publish_var()), unquote(port), [value])
      value
    end
  end

  @doc """
  Publish a list of values to `port`


  This macro works like `~>/2`, but publishes a list of output values to the port instead of a
  single value. Each value in the provided list will be sent to downstream components
  individually.

  ## Examples

  ```
  defcomponent MultiPublishExample do
    defcb publish(value) do
      value ~> some_port
      [:foo, :bar] ~>> some_other_port
    end
  end
  ```

      iex> Component.call(MultiPublishExample, :publish, [:bar]).publish
      [some_other_port: [:foo, :bar], some_port: [:bar]]
  """
  defmacro lst ~>> {port, _, _} when is_atom(port) do
    quote do
      lst = unquote(lst)
      unquote(publish_var()) = Keyword.put(unquote(publish_var()), unquote(port), lst)
      lst
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
      {:~>>, _env, [_, {name, _, _}]} -> name
      _ -> false
    end)
  end

  # defcallback
  # -----------

  @doc """
  Define a callback.

  This macro is used to define a callback function. Using this macro, a callback can be defined
  similar to a regular procedure. Inside the body of the procedure, `~>/2`, `~>>/2` `<~/2` and
  `sigil_f/2` can be used to access the state and to publish output. The macro ensures:

  - The function returns a `t:Skitter.Component.result/0` with the correct state (as updated by
  `<~/2`), publish (as updated by `~>/2` and `~>>/2`) and result (which contains the value of the
  last expression in `body`).

  - `c:Skitter.Component._sk_callback_info/2` and `c:Skitter.Callback._sk_callback_list/0` of the
  component module contains the required information about the defined callback.

  Note that, under the hood, `defcb/2` generates a regular elixir function. Therefore, pattern
  matching may still be used in the argument list of the callback. Attributes such as `@doc` may
  also be used as usual.

  ## Examples

  ```
  defcomponent CbExample do
    defcb simple(), do: nil
    defcb arguments(arg1, arg2), do: arg1 + arg2
    defcb state(), do: counter <~ (~f{counter} + 1)
    defcb publish_single(), do: ~D[1991-12-08] ~> out_port
    defcb publish_multi(), do: [~D[1991-12-08], ~D[2021-07-08]] ~>> out_port
  end
  ```

      iex> Component.callback_list(CbExample)
      [arguments: 2, publish_multi: 0, publish_single: 0, simple: 0, state: 0]

      iex> Component.callback_info(CbExample, :simple, 0)
      %Info{read: [], write: [], publish: []}

      iex> Component.callback_info(CbExample, :arguments, 2)
      %Info{read: [], write: [], publish: []}

      iex> Component.callback_info(CbExample, :state, 0)
      %Info{read: [:counter], write: [:counter], publish: []}

      iex> Component.callback_info(CbExample, :publish_single, 0)
      %Info{read: [], write: [], publish: [:out_port]}

      iex> Component.callback_info(CbExample, :publish_multi, 0)
      %Info{read: [], write: [], publish: [:out_port]}

      iex> Component.call(CbExample, :simple, %{}, [])
      %Result{result: nil, publish: [], state: %{}}

      iex> Component.call(CbExample, :arguments, %{}, [10, 20])
      %Result{result: 30, publish: [], state: %{}}

      iex> Component.call(CbExample, :state, %{counter: 10, other: :foo}, [])
      %Result{result: 11, publish: [], state: %{counter: 11, other: :foo}}

      iex> Component.call(CbExample, :publish_single, %{}, [])
      %Result{result: ~D[1991-12-08], publish: [out_port: [~D[1991-12-08]]], state: %{}}

      iex> Component.call(CbExample, :publish_multi, %{}, [])
      %Result{result: [~D[1991-12-08], ~D[2021-07-08]], publish: [out_port: [~D[1991-12-08], ~D[2021-07-08]]], state: %{}}
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
      @doc false
      @_sk_callbacks {{unquote(name), unquote(arity)}, unquote(info)}
      def unquote(name)(unquote(state_var), unquote_splicing(args)) do
        import unquote(__MODULE__), only: [sigil_f: 2, ~>: 2, ~>>: 2, <~: 2]
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
end
