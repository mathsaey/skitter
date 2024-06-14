# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy.Helpers do
  @moduledoc """
  Macros to be used in strategy hooks.

  This module defines various macro "primitives" which can be used to define strategies. These
  macros are only available inside `Skitter.DSL.Strategy.defhook/2`, where they are automatically
  imported.

  Internally, these macros call functions defined in various other modules. The information stored
  in the `t:Skitter.Strategy.context/0` passed to the hook is used to pass the appropriate
  information to these functions.
  """

  defmacro __using__(_) do
    quote do
      import Kernel, except: [send: 2]
      import unquote(__MODULE__)
      alias Skitter.{Operation, Worker, Remote}
    end
  end

  @doc """
  Raise a `Skitter.StrategyError`

  The error is automatically annotated with the current context, which is used to retrieve the
  current operation and strategy.


  ## Examples

      iex> defstrategy Example do
      ...>   defhook example, do: error("An error message")
      ...> end
      iex> Example.example(%Context{strategy: Example, operation: Foo})
      ** (Skitter.StrategyError) Raised by Skitter.DSL.Strategy.HelpersTest.Example handling Foo:
         An error message
  """
  defmacro error(message) do
    quote do
      raise Skitter.StrategyError,
        message: unquote(message),
        context: context()
    end
  end

  @doc """
  Create a worker using `Skitter.Worker.create_remote/4`.

  This macro creates a remote worker, automatically passing the current context.
  """
  defmacro remote_worker(state, role, placement \\ nil) do
    quote do
      Skitter.Worker.create_remote(context(), unquote(state), unquote(role), unquote(placement))
    end
  end

  @doc """
  Create a worker using `Skitter.Worker.create_local/3`.

  This macro creates a local worker, automatically passing the current context.
  """
  defmacro local_worker(state, role) do
    quote do
      Skitter.Worker.create_local(context(), unquote(state), unquote(role))
    end
  end

  @doc """
  Send a message to a worker using Elixir's `Kernel.send/2`.

  `send/2` and `send/3` defined in this module call `Skitter.Worker.send/2` which will send a
  message to a worker, eventually causing its `c:Skitter.Strategy.Operation.process/4` hook to be
  called.

  In contrast, this function uses the built-in `Kernel.send/2` of Elixir, which sends a message to
  a pid. This is useful when you need to use `Kernel.SpecialForms.receive/1` inside a hook.
  """
  defmacro plain_send(pid, message) do
    quote do
      Kernel.send(unquote(pid), unquote(message))
    end
  end

  @doc """
  Send a message to a worker with `Skitter.Worker.send/2`
  """
  defmacro send(worker, message) do
    quote(do: Skitter.Worker.send(unquote(worker), unquote(message)))
  end

  @doc """
  Emit data for the current context.

  Uses `Skitter.Strategy.Operation.emit/2`
  """
  defmacro emit(emit) do
    quote(do: Skitter.Strategy.Operation.emit(context(), unquote(emit)))
  end

  @doc """
  Stop the given worker using `Skitter.Worker.stop/1`
  """
  defmacro stop_worker(worker) do
    quote(do: Skitter.Worker.stop(unquote(worker)))
  end

  @doc """
  Stop the current worker using `Skitter.Worker.stop/1`
  """
  defmacro stop_worker do
    quote(do: Skitter.Worker.stop(self()))
  end

  @doc """
  Create an empty state for the operation.

  This macro creates an initial state for an operation, by using
  `Skitter.Operation.initial_state/2`

  ## Examples

      iex> defoperation ExampleOperation do
      ...>   initial_state :initial_state
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: initial_state()
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      :initial_state
  """
  defmacro initial_state(config \\ nil) do
    quote do
      Skitter.Operation.initial_state(operation(), unquote(config))
    end
  end

  @doc """
  Call `callback` of the current operation.

  Uses `Skitter.Operation.call/5`. The state, configuration and arguments can be passed through
  opts. If they are not provided, `:args` defaults to the empty list while `:state` and  `:config`
  default to `nil`.

  ## Examples

      iex> defoperation ExampleOperation do
      ...>   defcb example(arg), do: {arg, state(), config()}
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook empty_example(), do: call(:example).result
      ...>   defhook arg_example(), do: call(:example, args: [:foo]).result
      ...>   defhook state_example(), do: call(:example, args: [nil], state: :foo).result
      ...>   defhook config_example(), do: call(:example, args: [nil], config: :foo).result
      ...>   defhook all_example(), do: call(:example, args: [:foo], state: :foo, config: :foo).result
      ...> end
      iex> ExampleStrategy.arg_example(%Context{operation: ExampleOperation})
      {:foo, nil, nil}
      iex> ExampleStrategy.state_example(%Context{operation: ExampleOperation})
      {nil, :foo, nil}
      iex> ExampleStrategy.config_example(%Context{operation: ExampleOperation})
      {nil, nil, :foo}
      iex> ExampleStrategy.all_example(%Context{operation: ExampleOperation})
      {:foo, :foo, :foo}
      iex> ExampleStrategy.empty_example(%Context{operation: ExampleOperation})
      ** (UndefinedFunctionError) function Skitter.DSL.Strategy.HelpersTest.ExampleOperation.example/2 is undefined or private
  """
  defmacro call(callback, opts \\ []) do
    quote do
      Skitter.Operation.call(
        operation(),
        unquote(callback),
        unquote(Keyword.get(opts, :state, nil)),
        unquote(Keyword.get(opts, :config, nil)),
        unquote(Keyword.get(opts, :args, []))
      )
    end
  end

  @doc """
  Call `callback` of the current operation if it exists.

  Uses `Skitter.Operation.call_if_exists/5`. The state, configuration and arguments can be passed
  through opts (as in `call/3`). If they are not provided, `:args` defaults to the empty list
  while `:state` and `:config` default to `nil`.

  ## Examples

      iex> defoperation ExampleOperation, out: port do
      ...>   defcb exists do
      ...>     state <~ :exists
      ...>     :exists ~> port
      ...>     :exists
      ...>   end
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook exists_example(), do: call_if_exists(:exists)
      ...>   defhook does_not_exist_example(), do: call_if_exists(:does_not_exist)
      ...> end
      iex> ExampleStrategy.exists_example(%Context{operation: ExampleOperation})
      %Result{result: :exists, state: :exists, emit: [port: [:exists]]}
      iex> ExampleStrategy.does_not_exist_example(%Context{operation: ExampleOperation})
      %Result{result: nil, state: nil, emit: []}
  """
  defmacro call_if_exists(callback, opts \\ []) do
    quote do
      Skitter.Operation.call_if_exists(
        operation(),
        unquote(callback),
        unquote(Keyword.get(opts, :state, nil)),
        unquote(Keyword.get(opts, :config, nil)),
        unquote(Keyword.get(opts, :args, []))
      )
    end
  end

  @doc """
  Get the name of the in port with the given `index`.

  Calls `Skitter.Operation.index_to_in_port/2`.

  ## Examples

      iex> defoperation ExampleOperation, in: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: index_to_in_port(1)
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      :bar
  """
  defmacro index_to_in_port(index) do
    quote do
      Skitter.Operation.index_to_in_port(operation(), unquote(index))
    end
  end

  @doc """
  Get the name of the out port with the given `index`.

  Calls `Skitter.Operation.index_to_out_port/2`.

  ## Examples

      iex> defoperation ExampleOperation, out: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: index_to_out_port(0)
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      :foo
  """
  defmacro index_to_out_port(index) do
    quote do
      Skitter.Operation.index_to_out_port(operation(), unquote(index))
    end
  end

  @doc """
  Get the index of the given in `port`.

  Calls `Skitter.Operation.in_port_to_index/2`.

  ## Examples

      iex> defoperation ExampleOperation, in: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: in_port_to_index(:bar)
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      1
  """
  defmacro in_port_to_index(port) do
    quote do
      Skitter.Operation.in_port_to_index(operation(), unquote(port))
    end
  end

  @doc """
  Get the index of the given out `port`.

  Calls `Skitter.Operation.out_port_to_index/2`.

  ## Examples

      iex> defoperation ExampleOperation, out: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: out_port_to_index(:foo)
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      0
  """
  defmacro out_port_to_index(port) do
    quote do
      Skitter.Operation.out_port_to_index(operation(), unquote(port))
    end
  end

  @doc """
  Programmatically create output for the out port with `index`.

  The data must be wrapped in a list.

  ## Examples

      iex> defoperation ExampleOperation, out: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: to_port(0, [1, 2, 3])
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      [foo: [1, 2, 3]]
  """
  defmacro to_port(index, list) do
    quote do
      [{index_to_out_port(unquote(index)), unquote(list)}]
    end
  end

  @doc """
  Programmatically create output for all out ports.

  The data must be wrapped in a list.

  ## Examples

      iex> defoperation ExampleOperation, out: [foo, bar] do
      ...> end
      iex> defstrategy ExampleStrategy do
      ...>   defhook example(), do: to_all_ports([1, 2, 3])
      ...> end
      iex> ExampleStrategy.example(%Context{operation: ExampleOperation})
      [foo: [1, 2, 3], bar: [1, 2, 3]]
  """
  defmacro to_all_ports(list) do
    quote do
      operation()
      |> Skitter.Operation.out_ports()
      |> Enum.map(&{&1, unquote(list)})
    end
  end
end
