# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ComponentHandler do
  @moduledoc """
  Reactive component handler utilities.

  Handlers determine the behaviour of a component at compile -and runtime.
  This module documents handlers, and provides (private) utility functions which
  are used by skitter infrastructure to call these hooks at the appropriate
  time.

  Finally, it provides a macro which allows one to implement a
  component which acts as a component handler.
  """
  alias Skitter.{Component, Workflow, Registry}

  alias Skitter.MetaComponentHandler, as: Meta
  alias Skitter.Builtins.DefaultComponentHandler, as: Default

  @type t :: Meta | Component.t() | Workflow.t()

  # --------- #
  # Utilities #
  # --------- #

  # TODO: Figure out "built in" handlers
  # TODO: Allow workflow handlers
  # TODO: Document valid handlers
  @doc false
  def expand(Meta), do: Meta
  def expand(Default), do: Default
  def expand(handler = %Component{handler: Meta}), do: handler

  def expand(name) when is_atom(name) do
    case Registry.get(name) do
      nil -> throw {:error, :invalid_name, name}
      handler -> expand(handler)
    end
  end

  def expand(any), do: throw({:error, :invalid_handler, any})

  # ----- #
  # Hooks #
  # ----- #

  def on_compile_hook(c = %Component{handler: Meta}) do
    Meta.on_compile(c)
  end
end
