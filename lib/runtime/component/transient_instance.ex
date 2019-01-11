# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.TransientInstance do
  @moduledoc false

  alias Skitter.Runtime.Nodes

  defstruct [:ref]

  # TODO: Make it possible to load a component on a newly added node
  # Subsribe to node_join events and automatically load?

  def load(component, init_args) do
    ref = make_ref()
    res = Nodes.on_all(__MODULE__, :load_local, [ref, component, init_args])
    true = Enum.all?(res, &match?({:ok, ^ref}, &1))
    {:ok, %__MODULE__{ref: ref}}
  end

  def load_local(ref, component, init_args) do
    {:ok, instance} = Skitter.Component.init(component, init_args)
    :ok = :persistent_term.put(ref, instance)
    {:ok, ref}
  end
end

alias Skitter.Runtime.Component

defimpl Component.Instance, for: Component.TransientInstance do
  alias Skitter.Runtime.Component.TransientInstance.{Server, Supervisor}
  def react(instance, args) do
    ref = make_ref()
    {:ok, pid} = DynamicSupervisor.start_child(
      Supervisor, {Server, {instance.ref, args, self(), ref}}
    )
    {:ok, pid, ref}
  end
end
