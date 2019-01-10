# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.PermanentInstance do
  @behaviour Skitter.Runtime.Component.InstanceType
  @moduledoc false

  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Component.PermanentInstance.{Server, Supervisor}

  @impl true
  def supervisor(), do: Supervisor

  @impl true
  def load(ref, comp, init) do
    node = Nodes.select_permanent()
    DynamicSupervisor.start_child(
      {Supervisor, node}, {Server, {ref, comp, init}}
    )
  end

  @impl true
  def react(inst, args) do
    ref = make_ref()
    :ok = GenServer.cast(inst, {:react, args, self(), ref})
    {:ok, inst, ref}
  end
end
