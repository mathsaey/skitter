# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy definition DSL, see `strategy/1` and `defstrategy/2`.
  """
  alias Skitter.DSL.{AST, DefinitionError, Callback}
  alias Skitter.Strategy

  @doc """
  Define a strategy using `strategy/2` and bind it to `name`.
  """
  defmacro defstrategy(name, opts \\ [], do: body) do
    name_str = name |> AST.name_to_atom(__CALLER__) |> Atom.to_string()

    quote do
      unquote(name) = %{strategy(unquote(opts), do: unquote(body)) | name: unquote(name_str)}
    end
  end

  @doc """
  Define a `Skitter.Strategy`
  """
  @doc section: :dsl
  defmacro strategy(opts \\ [], do: body) do
    parents = opts |> Keyword.get(:extends, []) |> parse_parents()
    statements = AST.block_to_list(body)
    {statements, imports} = AST.extract_calls(statements, [:alias, :import, :require])

    callbacks =
      Callback.extract_callbacks(
        statements,
        imports,
        [:component, :deployment, :invocation],
        [],
        %{
          define: {[], []},
          deploy: {[:component], []},
          prepare: {[:component, :deployment_ref], []},
          send_token: {[:component, :deployment_ref, :invocation_ref], []},
          receive_token: {[:component, :deployment_ref, :invocation_ref], []},
          receive_message: {[:component, :deployment_ref, :invocation_ref], [:state, :publish]},
          drop_invocation: {[:component, :deployment_ref, :invocation_ref], []},
          drop_deployment: {[:component, :deployment_ref], []}
        }
      )

    quote do
      %Skitter.Strategy{}
      |> struct!(unquote(callbacks))
      |> Skitter.Strategy.merge(unquote(__MODULE__).verify_parents(unquote(parents)))
    end
  end

  defp parse_parents(lst) when is_list(lst), do: lst
  defp parse_parents(any), do: [any]

  @doc false
  def verify_parents(parents) do
    Enum.map(parents, fn
      s = %Strategy{} -> s
      other -> raise DefinitionError, "`#{inspect(other)}` is not a valid strategy"
    end)
  end
end
