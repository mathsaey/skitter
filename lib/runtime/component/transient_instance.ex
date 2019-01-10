# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.TransientInstance do
  @behaviour Skitter.Runtime.Component.InstanceType
  @moduledoc false

  alias Skitter.Runtime.Component.TransientInstance.{Server, Supervisor}
  alias Skitter.Runtime.Nodes

  # TODO: Make it possible to load a component on a newly added node

  @impl true
  def supervisor(), do: Supervisor

  @impl true
  def load(ref, component, init_args) do
    res = Nodes.on_all(__MODULE__, :load_local, [ref, component, init_args])
    true = Enum.all?(res, &match?({:ok, ^ref}, &1))
    {:ok, ref}
  end

  def load_local(ref, component, init_args) do
    {:ok, instance} = Skitter.Component.init(component, init_args)
    :ok = :persistent_term.put({__MODULE__, ref}, instance)
    {:ok, ref}
  end

  @impl true
  def react(key, args) do
    ref = make_ref()
    {:ok, pid} = DynamicSupervisor.start_child(
      Supervisor, {Server, {{__MODULE__, key}, args, self(), ref}}
    )
    {:ok, pid, ref}
  end
end
