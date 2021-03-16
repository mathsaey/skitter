# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Callback do
  @moduledoc """
  Callback definition DSL.

  This module offers a DSL which enables the definition of `Skitter.Callback` inside a module. In
  order to use this module, `use Skitter.DSL.Callback` needs to be added to the module definition.
  Afterwards, `defcb/2` can be used to define callbacks. Using this macro ensures the correct
  information is automatically added to `c:Skitter.Callback._sk_callback_info/1` and
  `c:Skitter.Callback._sk_callback_list/0`.

  Note that it is generally not needed to `import` or `use` this module manually, as
  `Skitter.DSL.Component.defcomponent/3` and `Skitter.DSL.Strategy.defstrategy/3` do this
  automatically.
  """

  alias Skitter.DSL.AST
  alias Skitter.Callback.Info

  # ------------------- #
  # Behaviour Callbacks #
  # ------------------- #

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [defcb: 2]

      @behaviour Skitter.Callback
      @before_compile {unquote(__MODULE__), :generate_behaviour_callbacks}
      Module.register_attribute(__MODULE__, :_sk_callbacks, accumulate: true)
    end
  end

  @doc false
  defmacro generate_behaviour_callbacks(env) do
    names =
      env.module
      |> Module.get_attribute(:_sk_callbacks)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()

    quote bind_quoted: [names: names] do
      @impl true
      def _sk_callback_list, do: unquote(names)

      # Prevent a warning if no callbacks are defined
      @impl true
      def _sk_callback_info(nil), do: %Skitter.Callback.Info{}

      for {name, info} <- @_sk_callbacks do
        def _sk_callback_info(unquote(name)), do: unquote(info)
      end
    end
  end

  # ------------------------- #
  # State & Publish Operators #
  # ------------------------- #

  @publish :_sk_publish
  @state :_sk_state

  @state_read_op :sigil_f
  @state_write_op :<~
  @publish_op :~>

  @doc """
  Read the state of a field.

  This macro reads the current value of `field` in the state passed to `Skitter.Callback.call/4`.

  This macro should only be used inside the body of `defcb/2`.

  ## Examples

      iex> defmodule ReadExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb read(), do: ~f{field}
      ...> end
      iex> Callback.call(ReadExample, :read, %{field: 5}, []).result
      5
      iex> Callback.call(ReadExample, :read, %{field: :foo}, []).result
      :foo
  """
  defmacro sigil_f({:<<>>, _, [str]}, _) do
    quote do
      Process.get(unquote(@state)).unquote(String.to_existing_atom(str))
    end
  end

  @doc """
  Update the state of a field.

  This macro should only be used inside the body of `defcallback/4`. It updates the value of
  `field` to `value` and returns `value` as its result. Note that `field` needs to exist inside
  `state`. If it does not exist, a `KeyError` will be raised.

  ## Examples

      iex> defmodule WriteExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb write(), do: field <~ :bar
      ...> end
      iex> Callback.call(WriteExample, :write, %{field: :foo}, []).state[:field]
      :bar
      iex> Callback.call(WriteExample, :write, %{field: :foo}, [])
      %Result{result: :bar, state: %{field: :bar}, publish: []}
      iex> Callback.call(WriteExample, :write, %{}, [])
      ** (KeyError) key :field not found
  """
  defmacro field <~ value do
    quote bind_quoted: [state: @state, field: AST.name_to_atom(field, __CALLER__), value: value] do
      Process.put(state, %{Process.get(state) | field => value})
      value
    end
  end

  @doc """
  Publish `value` to `port`

  This macro is used to specify `value` should be published on `port`. It should only be used
  inside the body of `defcb/2`. If a previous value was specified for `port`, it is overridden.

  ## Examples

      iex> defmodule PublishExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb publish(value) do
      ...>     value ~> some_port
      ...>     ~f{field} ~> some_other_port
      ...>   end
      ...> end
      iex> Callback.call(PublishExample, :publish, %{field: :foo}, [:bar]).publish
      [some_other_port: :foo, some_port: :bar]
  """
  defmacro value ~> port do
    port = AST.name_to_atom(port, __CALLER__)

    quote bind_quoted: [publish: @publish, port: port, value: value] do
      Process.put(publish, Keyword.put(Process.get(publish), port, value))
      value
    end
  end

  # ----------- #
  # defcallback #
  # ----------- #

  @doc """
  Define a callback.

  This macro is used to define a callback function. Using this macro, a callback can be defined
  similar to a regular procedure. Inside the body of the procedure, `~>/2`, `<~/2` and `sigil_f/2`
  can be used to access the state and to publish output. The macro ensures:

  - The function returns a `t:Skitter.Callback.result/0` with the correct state (as updated by
  `<~/2`), publish (as updated by `~>/2`) and result (which contains the value of the last
  expression in `body`).

  - `c:Skitter.Callback._sk_callback_info/1` and `c:Skitter.Callback._sk_callback_list/0` of the
  parent module contains the required information about the defined callback.

  Note that, under the hood, `defcb/2` generates a regular elixir function. Therefore, pattern
  matching may still be used in the argument list of the callback. Attributes such as `@doc` may
  also be used as usual.

  ## Examples

      iex> defmodule CbExample do
      ...>   use Skitter.DSL.Callback
      ...>
      ...>   defcb simple(), do: nil
      ...>   defcb arguments(arg1, arg2), do: arg1 + arg2
      ...>   defcb state(), do: counter <~ ~f{counter} + 1
      ...>   defcb publish(), do: ~D[1991-12-08] ~> out_port
      ...> end
      iex> Callback.info(CbExample, :simple)
      %Info{arity: 0, read?: false, write?: false, publish?: false}
      iex> Callback.info(CbExample, :arguments)
      %Info{arity: 2, read?: false, write?: false, publish?: false}
      iex> Callback.info(CbExample, :state)
      %Info{arity: 0, read?: true, write?: true, publish?: false}
      iex> Callback.info(CbExample, :publish)
      %Info{arity: 0, read?: false, write?: false, publish?: true}
      iex> Callback.call(CbExample, :simple, %{}, [])
      %Result{result: nil, publish: [], state: %{}}
      iex> Callback.call(CbExample, :arguments, %{}, [10, 20])
      %Result{result: 30, publish: [], state: %{}}
      iex> Callback.call(CbExample, :arguments, %{}, [10, 20, 30])
      ** (FunctionClauseError) no function clause matching in Skitter.DSL.CallbackTest.CbExample.arguments/2
      iex> Callback.call(CbExample, :state, %{counter: 10, other: :foo}, [])
      %Result{result: 11, publish: [], state: %{counter: 11, other: :foo}}
      iex> Callback.call(CbExample, :publish, %{}, [])
      %Result{result: ~D[1991-12-08], publish: [out_port: ~D[1991-12-08]], state: %{}}
  """
  defmacro defcb(signature, do: body) do
    {name, args} = Macro.decompose_call(signature)
    state_var = AST.internal_var(:state)

    # Need to escape this twice for some reason
    info = info(body, args) |> Macro.escape() |> Macro.escape()

    quote do
      @_sk_callbacks {unquote(name), unquote(info)}
      def unquote(name)(unquote(state_var), unquote(args)) do
        import unquote(__MODULE__), only: [sigil_f: 2, ~>: 2, <~: 2]

        Process.put(unquote(@state), unquote(state_var))
        Process.put(unquote(@publish), [])

        result = unquote(body)

        %Skitter.Callback.Result{
          result: result,
          state: Process.delete(unquote(@state)),
          publish: Process.delete(unquote(@publish))
        }
      end
    end
  end

  defp info(body, args) do
    %Info{
      arity: length(args),
      read?: AST.used?(body, @state_read_op),
      write?: AST.used?(body, @state_write_op),
      publish?: AST.used?(body, @publish_op)
    }
  end
end
