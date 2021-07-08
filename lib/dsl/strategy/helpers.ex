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
  Create a worker using `Skitter.Worker.create/4`.

  This macro creates a worker, automatically passing the current context.
  """
  defmacro create_worker(state, tag, placement \\ nil) do
    quote do
      Skitter.Worker.create(context(), unquote(state), unquote(tag), unquote(placement))
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
  Call `callback` of the current component with `state` and `args`.

  Uses `Skitter.Component.call/4`.
  """
  defmacro call_component(callback, state, args) do
    quote do
      Skitter.Component.call(component(), unquote(callback), unquote(state), unquote(args))
    end
  end

  @doc """
  Call `callback` of the current component with `args`.

  Uses `Skitter.Component.call/3`.
  """
  defmacro call_component(callback, args) do
    quote(do: Skitter.Component.call(component(), unquote(callback), unquote(args)))
  end

  @doc """
  Create the initial state of the component using `init` or an empty state.

  This macro creates an initial state for a component, either by calling the `:init` callback of
  the component, or by using `Skitter.Component.create_empty_state/1`. The init callback is only
  called if the component defines an init callback with an arity equal to the length of `args`.
  """
  defmacro init_or_initial_state(args) do
    quote do
      if {:init, length(unquote(args))} in Skitter.Component.callback_list(component()) do
        Skitter.Component.call(component(), :init, unquote(args)).state
      else
        Skitter.Component.create_empty_state(component())
      end
    end
  end
end
