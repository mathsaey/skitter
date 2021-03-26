# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.CallbackTest do
  use ExUnit.Case, async: true

  defmodule ModuleWithCallbacks do
    @behaviour Skitter.Callback
    alias Skitter.Callback.{Result, Info}

    def _sk_callback_list, do: [example: 1]

    def _sk_callback_info(:example, 1) do
      %Info{read: [:field], write: [], publish: [:arg]}
    end

    def example(state, arg) do
      result = Map.get(state, :field)
      %Result{state: state, publish: [arg: arg], result: result}
    end
  end

  alias Skitter.Callback.{Result, Info}
  import Skitter.Callback
  doctest Skitter.Callback

  test "call_inlined" do
    assert call_inlined(ModuleWithCallbacks, :example, %{field: "Skitter"}, [:some_argument]) ==
             %Result{
               state: %{field: "Skitter"},
               publish: [arg: :some_argument],
               result: "Skitter"
             }
  end
end
