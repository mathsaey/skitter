# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.OperationTest do
  use ExUnit.Case, async: true

  import Skitter.Operation
  alias Skitter.Operation.Callback.{Info, Result}

  defmodule OperationModule do
    @behaviour Skitter.Operation
    alias Skitter.Operation.Callback.{Info, Result}

    def _sk_operation_info(:strategy), do: Strategy
    def _sk_operation_info(:in_ports), do: [:input]
    def _sk_operation_info(:out_ports), do: [:output]

    def _sk_operation_initial_state, do: 42

    def _sk_callbacks, do: MapSet.new(example: 1)

    def _sk_callback_info(:example, 1) do
      %Info{read?: true, write?: false, emit?: true}
    end

    def example(state, config, arg) do
      result = state * config
      %Result{state: state, emit: [arg: arg], result: result}
    end
  end

  doctest Skitter.Operation
end
