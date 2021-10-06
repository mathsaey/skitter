# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy.Helpers do
  @moduledoc """
  Macros to be used in strategy hooks.

  This module defines various macro "primitives" to be used in `Skitter.DSL.Strategy.defhook/2`.
  The contents of this module are automatically available inside `defhook`.

  The macros defined in this module do not offer new functionality. Instead, they provide
  syntactic sugar over calling existing functions with arguments based on the context passed to
  the strategy hook.
  """

  defmacro __using__(_) do
    quote do
      import Kernel, except: [send: 2]
      import unquote(__MODULE__)
      alias Skitter.{Component, Worker, Invocation, Nodes}
    end
  end

  @doc """
  Raise a `Skitter.StrategyError`

  The error is automatically annotated with the current context, which is used to retrieve the
  current component and strategy.
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
  defmacro remote_worker(state, tag, placement \\ nil) do
    quote do
      Skitter.Worker.create_remote(context(), unquote(state), unquote(tag), unquote(placement))
    end
  end

  @doc """
  Create a worker using `Skitter.Worker.create_local/3`.

  This macro creates a local worker, automatically passing the current context.
  """
  defmacro local_worker(state, tag) do
    quote do
      Skitter.Worker.create_local(context(), unquote(state), unquote(tag))
    end
  end

  @doc """
  Send a message to a worker with `Skitter.Worker.send/3`

  The invocation is inferred from the current invocation.
  """
  defmacro send(worker, message) do
    quote(do: Skitter.Worker.send(unquote(worker), unquote(message), invocation()))
  end

  @doc """
  Send a message to a worker with `Skitter.Worker.send/3`
  """
  defmacro send(worker, message, invocation) do
    quote(do: Skitter.Worker.send(unquote(worker), unquote(message), unquote(invocation)))
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
  Call `callback` of the current component with `state`, `config` and `args`.

  Uses `Skitter.Component.call/5`.
  """
  defmacro call(callback, state, config, args) do
    quote do
      Skitter.Component.call(
        component(),
        unquote(callback),
        unquote(state),
        unquote(config),
        unquote(args)
      )
    end
  end

  @doc """
  Call `callback` of the current component with `args` and `config`.

  Uses `Skitter.Component.call/4`.
  """
  defmacro call(callback, config, args) do
    quote do
      Skitter.Component.call(component(), unquote(callback), unquote(config), unquote(args))
    end
  end

  @doc """
  Call `callback` of the current component with `args`.

  Uses `Skitter.Component.call/3`.
  """
  defmacro call(callback, args) do
    quote(do: Skitter.Component.call(component(), unquote(callback), unquote(args)))
  end

  @doc """
  Call `callback` of the current component with `args`.

  Uses `Skitter.Component.call/2`.
  """
  defmacro call(callback) do
    quote(do: Skitter.Component.call(component(), unquote(callback)))
  end

  @doc """
  Call `callback` of the current component if it exists.

  Uses `Skitter.Component.call_if_exists/5`.
  """
  defmacro call_if_exists(callback, state, config, args) do
    quote do
      Skitter.Component.call_if_exists(
        component(),
        unquote(callback),
        unquote(state),
        unquote(config),
        unquote(args)
      )
    end
  end

  @doc """
  Call `callback` of the current component if it exists.

  Uses `Skitter.Component.call_if_exists/4`.
  """
  defmacro call_if_exists(callback, config, args) do
    quote do
      Skitter.Component.call_if_exists(
        component(),
        unquote(callback),
        unquote(config),
        unquote(args)
      )
    end
  end

  @doc """
  Call `callback` of the current component if it exists.

  Uses `Skitter.Component.call_if_exists/3`.
  """
  defmacro call_if_exists(callback, args) do
    quote do
      Skitter.Component.call_if_exists(component(), unquote(callback), unquote(args))
    end
  end

  @doc """
  Call `callback` of the current component if it exists.

  Uses `Skitter.Component.call_if_exists/2`.
  """
  defmacro call_if_exists(callback) do
    quote do
      Skitter.Component.call_if_exists(component(), unquote(callback))
    end
  end

  @doc """
  Programmatically create output for the out port with `index`.

  The data must be wrapped in a list.
  """
  defmacro wrap_output(list, index \\ 0) do
    quote do
      port = Skitter.Component.index_to_out_port(component(), unquote(index))
      [{port, unquote(list)}]
    end
  end

  @doc """
  Send `message` to all out ports of the component.

  Generates a call to `Skitter.Component.meta_message_for_all_ports/2`.
  """
  defmacro meta_message_for_all_ports(message) do
    quote(do: Skitter.Component.meta_message_for_all_ports(component(), unquote(message)))
  end

  @doc """
  Create an empty state for the component.

  This macro creates an initial state for a component, by using
  `Skitter.Component.initial_state/1`
  """
  defmacro initial_state do
    quote do
      Skitter.Component.initial_state(component())
    end
  end
end
