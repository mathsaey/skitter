# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy definition DSL, see `defstrategy/2`.
  """
  alias Skitter.DSL.{AST, DefinitionError, Callback}
  alias Skitter.Strategy

  @doc """
  Define a `Skitter.Strategy`
  """
  @doc section: :dsl
  defmacro defstrategy(name \\ nil, opts \\ [], body)

  defmacro defstrategy(name, [], do: body) when is_list(name) do
    quote do
      defstrategy(nil, unquote(name), do: unquote(body))
    end
  end

  defmacro defstrategy(name, opts, do: body) do
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
          prepare: {[:component, :deployment], []},
          send_token: {[:component, :deployment, :invocation], []},
          receive_token: {[:component, :deployment, :invocation], []},
          receive_message: {[:component, :deployment, :invocation], [:state, :publish]},
          drop_invocation: {[:component, :deployment, :invocation], []},
          drop_deployment: {[:component, :deployment], []}
        }
      )

    quote do
      require Skitter.DSL.Registry

      %Skitter.Strategy{name: unquote(name)}
      |> struct!(unquote(callbacks))
      |> Skitter.Strategy.merge(unquote(__MODULE__).expand_parents(unquote(parents)))
      |> Skitter.DSL.Registry.store(unquote(name))
    end
  end

  defp parse_parents(lst) when is_list(lst), do: lst
  defp parse_parents(any), do: [any]

  @doc false
  def expand_parents(parents), do: Enum.map(parents, &expand_parent/1)

  defp expand_parent(s = %Strategy{}), do: s

  defp expand_parent(name) when is_atom(name) do
    name |> Skitter.DSL.Registry.lookup!() |> expand_parent()
  end

  defp expand_parent(any) do
    raise DefinitionError, "`#{inspect(any)}` is not a valid strategy"
  end
end
