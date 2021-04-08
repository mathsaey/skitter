# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DefinitionError do
  @moduledoc """
  Raised when an error is encountered in a Component, Workflow or Strategy.

  This error can be raised by a Skitter DSL or by a skitter data type. It is raised when invalid
  syntax is encountered or when a semantic error is present in a `Skitter.Component`,
  `Skitter.Workflow` or `Skitter.Strategy`.
  """
  defexception [:message, :env]

  @impl true
  def message(%__MODULE__{message: msg, env: nil}) do
    msg
  end

  def message(%__MODULE__{message: msg, env: env}) do
    loc = Exception.format_file_line(env.file, env.line, " ")
    loc <> msg
  end

  @impl true
  def exception(msg) when is_binary(msg), do: %__MODULE__{message: msg}
  def exception({msg, env}), do: %__MODULE__{message: msg, env: env}

  @doc false
  def inject(msg, env \\ nil) do
    env = Macro.escape(env)
    quote(do: raise(Skitter.DefinitionError, {unquote(msg), unquote(env)}))
  end
end
