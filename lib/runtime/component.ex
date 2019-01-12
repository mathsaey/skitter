# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component do
  @moduledoc false

  alias __MODULE__.{
    Instance, MasterSupervisor, WorkerSupervisor,
    TransientInstance, PermanentInstance
  }

  # TODO: Make it possible to unload a component instance
  # TODO: Make it possbible to load an instance on a newly added node

  def supervisor(:master), do: MasterSupervisor
  def supervisor(:worker), do: WorkerSupervisor

  @doc """
  Load the runtime version of the component instance.

  `comp` and `init_args` will be passed to `Skitter.Component.init/2`.
  This callback will return `{:ok, some_data}` when successful, `some_data` can
  be passed as an argument to `react/2`
  """
  def load(comp, init_args) do
    mod = select(comp)
    mod.load(comp, init_args)
  end

  @doc """
  Ask the component instance to react to incoming data.

  The first argument should be the return value of `load/2`, the second value
  should be the list of arguments which will be passed to
  `Skitter.Component.react/2`.

  This functions returns a tuple containing `:ok`, the pid of the process
  which reacts, and a unique reference for this invocation of react.
  When the instance has finished reacting, the process which made the react
  request will receive the following tuple: `{:react_finished, ref, spits}`,
  where ref is the reference that was returned from the function, while spits
  contains the spits produced by the invocation of react.
  """
  def react(instance = %Instance{mod: mod}, args) do
    mod.react(instance, args)
  end

  defp select(comp) do
    if Skitter.Component.state_change?(comp) do
      PermanentInstance
    else
      TransientInstance
    end
  end
end
