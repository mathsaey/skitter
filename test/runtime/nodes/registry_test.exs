# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.NodeRegistryTest do
  use ExUnit.Case, async: true
  alias Skitter.Runtime.Nodes.Registry

  setup do
    on_exit fn ->
      Supervisor.restart_child(
        Skitter.Runtime.Nodes.MasterSupervisor,
        Skitter.Runtime.Nodes.Registry
      )
    end
  end

  test "if adding and removing nodes works" do
    Registry.add(:not_a_real_node)

    assert Registry.all() == [:not_a_real_node]
    assert Registry.get(:not_a_real_node) == %Registry{}

    Registry.remove(:not_a_real_node)

    assert Registry.all() == []
    assert Registry.get(:not_a_real_node) == nil
  end

  test "if updating works" do
    Registry.add(:node)
    Registry.update(:node, connected: true, monitor: :foo)
    assert Registry.get(:node) == %Registry{connected: true, monitor: :foo}
  end
end
