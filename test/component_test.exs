# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component

  defmodule ComponentModule do
    @behaviour Skitter.Component
    @behaviour Skitter.Callback

    alias Skitter.Callback.{Info, Result}

    defstruct [:field]

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_callback_list, do: [:example]

    def _sk_callback_info(:example) do
      %Info{arity: 1, read?: true, write?: false, publish?: false}
    end

    def example(state, args) do
      %Result{result: args, state: state, publish: []}
    end
  end

  doctest Skitter.Component
end
