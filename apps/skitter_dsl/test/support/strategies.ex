# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.TestSupport.Strategies do
  @moduledoc false
  require Skitter.DSL.Named

  alias Skitter.{Callback, Callback.Result, Strategy}

  @doc """
  Create strategies required for testing
  """
  def create do
    # Define this as a struct so this can work even if the strategy DSL is broken
    # Use `:todo` to trick the dsl into thinking the strategy is complete
    %Strategy{
      name: TestStrategy,
      define: %Callback{function: fn _, [component] -> %Result{result: component} end},
      deploy: :todo,
      prepare: :todo,
      send_token: :todo,
      receive_token: :todo,
      receive_message: :todo,
      drop_deployment: :todo,
      drop_invocation: :todo
    }
    |> Skitter.DSL.Named.store(TestStrategy)
  end
end
