# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy and Hook definition DSL.

  This module offers macros to define a strategy and its hooks. A strategy is defined through the
  use of the `defstrategy/3` macro. Inside the body of `defstrategy/3`, `defhook/2` can be used
  to define a hook. The other macros in this module can be used inside the body of `defhook/2` to
  obtain information from the current `t:Skitter.Strategy.context/0`. We recommend reading the
  documentation of `defstrategy/3` to get started.
  """
  alias Skitter.DSL.AST

  # -------- #
  # Strategy #
  # -------- #

  @doc """
  Define a strategy.

  This macro is used to define a strategy. A `Skitter.Strategy` is defined as a regular Elixir
  module which defines several _hooks_. As such, any code that is valid inside an Elixir module
  (such as function definitions or module attributes) is valid inside `defstrategy/3`.
  Additionally, the `defhook/2` macro may be used to define a Skitter _hook_. Hooks are special
  Elixir functions which accept a `t:Skitter.Strategy.context/0` argument.

  ## Extending Strategies

  Strategies can be created based on existing strategies. This is done by _extending_ some
  strategy. When a strategy extends another strategy, it will inherit all the hooks defined by the
  strategy it extends:

      iex> defstrategy Parent do
      ...>   defhook example, do: :example_hook
      ...> end
      iex> defstrategy Child, extends: Parent do
      ...> end
      iex> Child.example(%Context{})
      :example_hook

  Inherited hooks can be overridden:

      iex> defstrategy Parent do
      ...>   defhook example, do: :parent
      ...> end
      iex> defstrategy Child, extends: Parent do
      ...>   defhook example, do: :child
      ...> end
      iex> Child.example(%Context{})
      :child

  Finally, a strategy can extend multiple parent strategies. When this is done, the hooks of
  earlier parent strategies take precedence over later hooks:

      iex> defstrategy Parent1 do
      ...>   defhook example, do: :parent1
      ...> end
      iex> defstrategy Parent2 do
      ...>   defhook example, do: :parent2
      ...>   defhook another, do: :parent2
      ...> end
      iex> defstrategy Child, extends: [Parent1, Parent2] do
      ...> end
      iex> Child.example(%Context{})
      :parent1
      iex> Child.another(%Context{})
      :parent2
  """
  defmacro defstrategy(name, opts \\ [], do: body) do
    parents = opts |> Keyword.get(:extends, []) |> parse_parents()

    quote do
      defmodule unquote(name) do
        # Required for hook "inheritance"
        @_sk_parents unquote(parents)
        @before_compile {unquote(__MODULE__), :add_parent_hooks}
        @before_compile {unquote(__MODULE__), :store_modules}
        Module.register_attribute(__MODULE__, :_sk_hook, accumulate: true)

        import unquote(__MODULE__), only: [defhook: 2]

        unquote(body)
      end
    end
  end

  defp parse_parents(lst) when is_list(lst), do: lst
  defp parse_parents(any), do: [any]

  # ----- #
  # Hooks #
  # ----- #

  defp context_var, do: quote(do: var!(context, unquote(__MODULE__)))

  @doc """
  Obtain the context struct.

  A strategy hook is called with a `t:Skitter.Strategy.context/0` as its first argument. This
  macro is used to obtain this struct.

  ## Examples

      iex> defstrategy FullContext do
      ...>   defhook read, do: context()
      ...> end
      iex> FullContext.read(%Context{operation: SomeOperation})
      %Context{operation: SomeOperation}
  """
  defmacro context do
    quote do
      unquote(context_var())
    end
  end

  @doc """
  Obtain the context's operation.

  ## Examples

      iex> defstrategy ReadOperation do
      ...>   defhook read, do: operation()
      ...> end
      iex> ReadOperation.read(%Context{operation: SomeOperation})
      SomeOperation
  """
  defmacro operation, do: quote(do: context().operation)

  @doc """
  Obtain the context's strategy.

  ## Examples

      iex> defstrategy ReadStrategy do
      ...>   defhook read, do: strategy()
      ...> end
      iex> ReadStrategy.read(%Context{strategy: ReadStrategy})
      Skitter.DSL.StrategyTest.ReadStrategy
  """
  defmacro strategy, do: quote(do: context().strategy)

  @doc """
  Obtain the context's deployment.

  ## Examples

      iex> defstrategy ReadDeployment do
      ...>   defhook read, do: deployment()
      ...> end
      iex> ReadDeployment.read(%Context{deployment: :some_deployment_data})
      :some_deployment_data
  """
  defmacro deployment, do: quote(do: context().deployment)

  @doc """
  Define a hook.

  This macro defines a strategy hook. Hooks are functions called by the Skitter runtime system in
  response to predefined events (described in `Skitter.Strategy.Operation`), or by other hooks.
  Internally, hooks are plain Elixir functions which accept a `t:Skitter.Strategy.context/0` as
  their first argument. This macro generates a plain Elixir function which accepts such a context.

  Said otherwise, the following two definitions are equivalent:

  ```
  def my_hook(context, arg1, arg2), do: ...
  ```

  ```
  defhook my_hook(arg1, arg2), do: ...
  ```

  Using the `defhook/2` macro, however, ensures hooks can be inherited (as described in
  `defstrategy/3`), and offers access to the macros defined in `Skitter.DSL.Strategy.Helpers`,
  which provide the building blocks required to build a strategy. The `context/0`, `operation/0`,
  `strategy/0` and `deployment/0` macros can be used to obtain the information stored in the
  context the hook was called with.

  ## Calling hooks

  Since hooks are plain Elixir functions, they may be called like any other function. However, a
  `t:Skitter.Strategy.context/0` must be provided:

      iex> defstrategy Strategy do
      ...>   defhook hook, do: "hello"
      ...> end
      iex> Strategy.hook(%Context{})
      "hello"

  When a hook calls another hook (defined in another strategy or in the same strategy), it _must_
  use the `context/0` macro to pass the current context.

      iex> defstrategy S1 do
      ...>   defhook example, do: "world!"
      ...> end
      iex> defstrategy S2 do
      ...>   defhook example, do: "Hello, " <> S1.example(context())
      ...> end
      iex> S2.example(%Context{})
      "Hello, world!"

      iex> defstrategy Local do
      ...>   defhook left, do: "Hello, "
      ...>   defhook right, do: "world!"
      ...>   defhook example, do: left(context()) <> right(context())
      ...> end
      iex> Local.example(%Context{})
      "Hello, world!"

  Since the context contains the current strategy, it is possible to dynamically call the current
  strategy. However, the syntax for this is rather unwieldy:

      iex> defstrategy AbstractAnimal do
      ...>   defhook example, do: "Animal says: " <> strategy().say(context())
      ...> end
      iex> defstrategy Dog, extends: AbstractAnimal do
      ...>   defhook say, do: "woof!"
      ...> end
      iex> Dog.example(%Context{strategy: Dog})
      "Animal says: woof!"
      iex> defstrategy Cat, extends: AbstractAnimal do
      ...>   defhook say, do: "meow!"
      ...> end
      iex> Cat.example(%Context{strategy: Cat})
      "Animal says: meow!"

  Note that we have to explicitly pass the strategy as a part of the context in the examples
  above. In a real application, the Skitter Runtime calls hooks, ensuring the appropriate context
  is passed.
  """
  defmacro defhook(clause, do: body) do
    {name, args, guards} = AST.decompose_clause(clause)

    body =
      quote do
        use unquote(__MODULE__).Helpers, hook: unquote(name)

        import unquote(__MODULE__),
          only: [
            context: 0,
            operation: 0,
            strategy: 0,
            deployment: 0
          ]

        unquote(body)
      end

    gen_hook(name, args, guards, quote(do: __MODULE__), body)
  end

  # Generate a hook implementation, store the module that defined the hook
  defp gen_hook(name, args, guards, module, body) do
    quote do
      @doc false
      @_sk_hook {{unquote(name), unquote(length(args))}, unquote(module)}
      def unquote(AST.build_clause(name, [context_var() | args], guards)) do
        unquote(body)
      end
    end
  end

  # Create an AST that calls a hook in a module
  defp gen_hook_call(module, hook, args) do
    quote do
      unquote(module).unquote(hook)(unquote(context_var()), unquote_splicing(args))
    end
  end

  # Get the list of hooks defined in the module
  defp get_hooks(mod), do: mod |> Module.get_attribute(:_sk_hook, []) |> Enum.map(&elem(&1, 0))

  @doc false
  # Add all the parent hooks that are not present in the strategy module.
  # This is done by generating a hook which calls the hook of the module that defined the hook
  defmacro add_parent_hooks(env) do
    hooks = env.module |> get_hooks() |> MapSet.new()

    hooks =
      env.module
      |> Module.get_attribute(:_sk_parents)
      |> Enum.map_reduce(hooks, fn parent, hooks ->
        # Find the hooks not present in strategy which are present in parent
        to_add = parent._sk_hooks() |> MapSet.new() |> MapSet.difference(hooks)

        # Generate calls to the original module that defined the hook
        stubs =
          Enum.map(to_add, fn {hook, arity} ->
            module = parent._sk_hook_module(hook, arity)
            args = Macro.generate_arguments(arity, __MODULE__)
            gen_hook(hook, args, nil, module, gen_hook_call(module, hook, args))
          end)

        {quote(do: (unquote_splicing(stubs))), MapSet.union(hooks, to_add)}
      end)
      |> elem(0)

    quote do
      (unquote_splicing(hooks))
    end
  end

  @doc false
  # Store the original module of each hook. This is used by add_parent_hooks to generate a call to
  # the proper module when inheriting a hook.
  defmacro store_modules(env) do
    modules = env.module |> Module.get_attribute(:_sk_hook) |> Map.new() |> Macro.escape()
    names = env.module |> get_hooks() |> Macro.escape()

    quote bind_quoted: [modules: modules, names: names] do
      def _sk_hooks, do: unquote(names)

      for {{name, arity}, module} <- modules do
        def _sk_hook_module(unquote(name), unquote(arity)), do: unquote(module)
      end
    end
  end
end
