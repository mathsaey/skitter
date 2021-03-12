# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.CallbackTest do
  use ExUnit.Case, async: true

  defmodule ModuleWithCallbacks do
    @behaviour Skitter.Callback
    alias Skitter.Callback.{Result, Info}

    def _sk_callback_list, do: [:example]

    def _sk_callback_info(:example) do
      %Info{arity: 1, read?: true, write?: false, publish?: true}
    end

    def example(state, [arg1]) do
      %Result{state: state, publish: [arg1: arg1], result: :some_value}
    end
  end

  alias Skitter.Callback.{Result, Info}
  import Skitter.Callback
  doctest Skitter.Callback
end
