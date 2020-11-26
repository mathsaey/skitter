# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  alias Skitter.Callback
  alias Skitter.Callback.Result

  alias Skitter.Component
  import Skitter.Component
  doctest Skitter.Component

  test "fetch" do
    c = %Component{callbacks: %{callback: %Callback{}}}
    assert c[:doesnotexist] == nil
    assert %Callback{} = c[:callback]
  end

  test "pop" do
    c = %Component{callbacks: %{callback: %Callback{}}}

    {val, comp} = Access.pop(c, :doesnotexist)
    assert %Callback{} = comp[:callback]
    assert val == nil

    {val, comp} = Access.pop(c, :callback)
    assert comp[:callback] == nil
    assert %Callback{} = val
  end

  test "get_and_update" do
    c = %Component{callbacks: %{callback: %Callback{}}}

    {val, comp} = Access.get_and_update(c, :callback, fn _ -> :pop end)
    assert comp[:callback] == nil
    assert %Callback{} = val
  end
end
