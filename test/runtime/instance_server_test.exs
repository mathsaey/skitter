# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.InstanceServerTest do
  use ExUnit.Case, async: true

  import Skitter.Component, only: [component: 3]
  alias Skitter.Runtime.InstanceServer

  component TestComponent, in: val, out: current do
    effect state_change
    fields ctr

    init x do
      ctr <~ x
    end

    react _val do
      ctr <~ ctr + 1
      ctr ~> current
    end
  end

  test "If the server works" do
    {:ok, pid} = InstanceServer.start_link(TestComponent, 5)
    {:ok, spits} = InstanceServer.react(pid, [:foo])

    assert spits == [current: 6]
  end

  doctest Skitter.Runtime.InstanceServer
end
