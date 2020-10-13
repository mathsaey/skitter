# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy definition DSL, see `defstrategy/2`.
  """
  alias Skitter.DSL.{AST, Callback}

  @doc """
  Define a `Skitter.Strategy`
  """
  defmacro defstrategy(name \\ nil, do: body) do
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
      require Skitter.DSL.Named

      %Skitter.Strategy{name: unquote(name)}
      |> struct!(unquote(callbacks))
      |> Skitter.DSL.Named.store(unquote(name))
    end
  end
end
