# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.TransientInstance do
  @behaviour Skitter.Runtime.Component.RuntimeInstanceType
  @moduledoc false

  alias Skitter.Runtime.Component.TransientInstance.{Server, Supervisor}

  @impl true
  def supervisor(), do: Supervisor

  @impl true
  def load_method, do: :all

  @impl true
  def load(supervisor, component, init_args) do
    key = make_ref()
    {:ok, instance} = Skitter.Component.init(component, init_args)
    :persistent_term.put({__MODULE__, key}, instance)
    {:ok, {key, supervisor}}
  end

  @impl true
  def react({key, sup}, args) do
    ref = make_ref()
    {:ok, pid} = DynamicSupervisor.start_child(
      sup,
      {Server, {{__MODULE__, key}, args, self(), ref}}
    )
    {:ok, pid, ref}
  end
end
