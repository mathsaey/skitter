# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.StrategyTest do
  use ExUnit.Case, async: true

  import Skitter.Strategy
  alias Skitter.{Component, Callback, Callback.Result}

  doctest Skitter.Strategy

  describe "component handler" do
    test "on_define" do
      strategy = %Component{
        callbacks: %{
          on_define: %Callback{
            function: fn _state, [component] ->
              %Result{result: %{component | fields: [:foobar]}}
            end
          }
        }
      }

      assert on_define(%Component{strategy: strategy}).fields == [:foobar]
    end
  end

  describe "module handler" do
    test "on_define" do
      defmodule OnDefineModule do
        def on_define(c), do: %{c | fields: [:foobar]}
      end

      assert on_define(%Component{strategy: OnDefineModule}).fields == [:foobar]
    end
  end
end
