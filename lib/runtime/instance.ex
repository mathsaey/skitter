# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Instance do
  @moduledoc false

  alias Skitter.Runtime.Instance.{Server, Supervisor}

  @doc """
  Returns a SuperVisor module that should be used to supervise instances.
  """
  def supervisor(), do: Supervisor

  @doc """
  Spawn a GenServer which will manage a component instance.

  `component` should be a skitter component module. This component should be
  stateful. `init_args` are passed along to the `Skitter.Component.init/2`
  function. The id should uniquely identify this component within a skitter
  workflow. Typically, the name of the proto-instance is used for this.
  """
  def start_linked_instance(id, component, init_args) do
    Server.start_link({id, component, init_args})
  end

  @doc """
  Like `start_linked_instance:2`, but spawns the server under a supervisor.

  The supervisor should be a supervisor returned by `supervisor/0`
  """
  def start_supervised_instance(supervisor, id, component, init_args) do
    DynamicSupervisor.start_child(
      supervisor, {Server, {id, component, init_args}}
    )
  end

  @doc """
  Fetch the id of a component instance.
  """
  def id(inst, timeout \\ :infinity), do: GenServer.call(inst, :id, timeout)

  @doc """
  Make a server react to incoming data.

  Calls the `Skitter.Component.react/2` function on the component instance with
  args. This is a blocking operation which will wait infinitely by default.
  """
  def react(inst, args, timeout \\ :infinity) do
    GenServer.call(inst, {:react, args}, timeout)
  end
end
