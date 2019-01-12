# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.PermanentInstance do
  @moduledoc false

  use Skitter.Runtime.Component.Instance

  alias Skitter.Runtime.Nodes
  alias __MODULE__.{Server, Supervisor}

  def load(comp, init) do
    node = Nodes.select_permanent()
    {:ok, pid} = DynamicSupervisor.start_child(
      {Supervisor, node}, {Server, {make_ref(), comp, init}}
    )
    {:ok, create_instance(pid)}
  end

  def react(instance_ref(), args) do
    ref = make_ref()
    :ok = GenServer.cast(instance_ref, {:react, args, self(), ref})
    {:ok, instance_ref, ref}
  end
end
