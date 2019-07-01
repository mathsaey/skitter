# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.InstanceTest do
  use ExUnit.Case, async: true
  alias Skitter.Component.Instance
  import Skitter.Component.Instance

  import Skitter.Component

  setup_all do
    component = defcomponent([in: [a], out: [x, y, z]], do: nil)
    instance = %Instance{component: component}
    [component: component, instance: instance]
  end

  test "add link", %{instance: instance} do
    assert(
      (instance
       |> add_link(:x, {:foo, :a})
       |> add_link(:y, {:bar, :b})
       |> add_link(:x, {:baz, :c})).links ==
        %{x: [baz: :c, foo: :a], y: [bar: :b]}
    )
  end
end
