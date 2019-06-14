# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.CallbackTest do
  use ExUnit.Case, async: true
  alias Skitter.Component.Callback
  import Skitter.Component.Callback
  doctest Skitter.Component.Callback

  test "create/3" do
    f = fn state, [_] -> {:ok, state, nil} end

    func = create(f, :read, false)

    struct = %Callback{
      function: f,
      state_capability: :read,
      publish_capability: false
    }

    assert func == struct
  end
end
