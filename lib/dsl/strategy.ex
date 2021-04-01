# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy and Hook definition DSL.

  This module offers macros to define a strategy and hooks. To define a strategy, use
  `defstrategy/3`. Inside the strategy, `defhook/2` can be used to define hooks. Inside the body
  of the hook, `sigil_c/2` can be used to read the current context.

  Note that it is possible to define a strategy as an elixir module which implements the
  `Skitter.Strategy` behaviour. Using `defstrategy/3` instead offers two main advantages:

  - The `t:Skitter.Strategy.context/0` of a hook is passed as an implicit argument, which can be
  accessed through the `sigil_c/2` macro.
  - A trait-like mechanism is introduced, which can be used to create new strategies based on
  existing ones.

  ## Examples

  Many strategies in this module's documentation extend the `Dummy` strategy. This is done to
  prevent warnings related to the `Skitter.Strategy` behaviour and should not be considered a part
  of the example code.
  """

  # -------- #
  # Strategy #
  # -------- #

  @doc """
  Define a strategy.

  This macro is used to define a strategy module. Through the use of this macro, a strategy module
  can be defined from scratch or based on one or more existing strategies. This macro enables the
  use of `defhook/2`, which is used to define a strategy _hook_.

  A hook is an elixir function which accepts a `t:Skitter.Strategy.context/0` as its first
  argument. This context argument is implicitly created by the `defhook/2` macro; the various
  fields of the context can be accessed through the use of `sigil_c/2`.

  Besides the context argument, hooks offer one additional feature: they can be inherited by other
  strategies.

  ## Extending Strategies

  A strategy can be created based on an existing strategy. This is done by _extending_ some
  strategy. When a strategy extends another strategy, it will inherit all the hooks defined by the
  strategy it extends:

      iex> defstrategy Parent, extends: Dummy do
      ...>   defhook example, do: :example_hook
      ...> end
      iex> defstrategy Child, extends: Parent do
      ...> end
      iex> Child.example(%Context{})
      :example_hook

  Inherited hooks can be overridden:

      iex> defstrategy Parent, extends: Dummy do
      ...>   defhook example, do: :parent
      ...> end
      iex> defstrategy Child, extends: Parent do
      ...>   defhook example, do: :child
      ...> end
      iex> Child.example(%Context{})
      :child

  Finally, a strategy can extend multiple parent strategies. When this is done, the hooks of
  earlier parent strategies take precedence over later hooks:

      iex> defstrategy Parent1, extends: Dummy do
      ...>   defhook example, do: :parent1
      ...> end
      iex> defstrategy Parent2, extends: Dummy do
      ...>   defhook example, do: :parent2
      ...>   defhook another, do: :parent2
      ...> end
      iex> defstrategy Child, extends: [Parent1, Parent2] do
      ...> end
      iex> Child.example(%Context{})
      :parent1
      iex> Child.another(%Context{})
      :parent2

  Note that some caveats apply when hooks call other hooks. These are described in the
  documentation of `defhook/2`.
  """
  defmacro defstrategy(name, opts \\ [], do: body) do
    parents = opts |> Keyword.get(:extends, []) |> parse_parents()

    quote do
      defmodule unquote(name) do
        @behaviour Skitter.Strategy

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
  Read context information.

  A strategy hook is called with a `t:Skitter.Strategy.context/0` as its first argument. This
  macro is used to access the context fields.

  ## Examples

      iex> defstrategy ReadContext, extends: Dummy do
      ...>   defhook read_component, do: ~c{component}
      ...> end
      iex> ReadContext.read_component(%Context{component: SomeComponent})
      SomeComponent

  """
  defmacro sigil_c({:<<>>, _, [str]}, _) do
    field = str |> String.to_atom()

    quote do
      context().unquote(field)
    end
  end

  @doc """
  Obtain the context struct.

  A strategy hook is called with a `t:Skitter.Strategy.context/0` as its first argument. This
  macro is used to obtain this struct.

  ## Examples

      iex> defstrategy FullContext, extends: Dummy do
      ...>   defhook read, do: context()
      ...> end
      iex> FullContext.read(%Context{component: SomeComponent})
      %Context{component: SomeComponent}
  """
  defmacro context do
    quote do
      unquote(context_var())
    end
  end

  @doc """
  Define a hook.

  This macro defines a single hook of a strategy. While a hook may be defined as a plain elixir
  function, using this macro offers two advantages:

  - The hook context is handled by the macro and can be accessed with `sigil_c/2`.
  - Other strategies can inherit this hook, making it easier to create new strategies. This is
  shown in the documentation of `defstrategy/3`.

  ## Calling hooks

  Hooks defined inside other strategies may be called like a normal elixir function inside the
  body of a hook. When this occurs, `defhook/2` automatically passes the context argument to the
  hook that is called.

      iex> defstrategy S1, extends: Dummy do
      ...>   defhook example, do: "world!"
      ...> end
      iex> defstrategy S2, extends: Dummy do
      ...>   defhook example, do: "Hello, " <> S1.example()
      ...> end
      iex> S2.example(%Context{})
      "Hello, world!"

  The same cannot be done when a local hook (i.e. a hook defined in the current module) is called.
  Therefore, a local hook should be called with a context argument. `context/0` can be used for
  this:

      iex> defstrategy Local, extends: Dummy do
      ...>   defhook left, do: "Hello, "
      ...>   defhook right, do: "world!"
      ...>   defhook example, do: left(context()) <> right(context())
      ...> end
      iex> Local.example(%Context{})
      "Hello, world!"

  A hook of a child strategy can also be called dynamically in a similar way:

      iex> defstrategy Abstract, extends: Dummy do
      ...>   defhook example, do: "Child says: " <> ~c{strategy}.say(context())
      ...> end
      iex> defstrategy Child, extends: Abstract do
      ...>   defhook say, do: "Hello!"
      ...> end
      iex> Child.example(%Context{strategy: Child})
      "Child says: Hello!"

  """
  defmacro defhook(signature, do: body) do
    {name, args} = Macro.decompose_call(signature)
    body = Macro.prewalk(body, &maybe_modify_call(Macro.decompose_call(&1), &1, __CALLER__))

    body =
      quote do
        import Kernel, except: [sigil_c: 2]
        import unquote(__MODULE__), only: [context: 0, sigil_c: 2]
        unquote(body)
      end

    gen_hook(name, args, quote(do: __MODULE__), body)
  end

  # Pass the context when a parent hook is called
  defp maybe_modify_call({module, func, args}, node, env) do
    mod = Macro.expand(module, env)
    strategy_dsl_module? = is_atom(mod) and :erlang.function_exported(mod, :_sk_hooks, 0)
    hook_call? = strategy_dsl_module? and {func, length(args)} in mod._sk_hooks()
    if hook_call?, do: gen_hook_call(module, func, args), else: node
  end

  defp maybe_modify_call(_, node, _), do: node

  # Generate a hook implementation, store the module that defined the hook
  defp gen_hook(name, args, module, body) do
    quote do
      @_sk_hook {{unquote(name), unquote(length(args))}, unquote(module)}
      def unquote(name)(unquote(context_var()), unquote_splicing(args)) do
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
            gen_hook(hook, args, module, gen_hook_call(module, hook, args))
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
