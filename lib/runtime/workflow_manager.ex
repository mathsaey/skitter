# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.WorkflowManager do
  @moduledoc false

  use GenServer

  alias Skitter.{Remote, Runtime}

  alias Skitter.Runtime.Config
  alias Skitter.Mode.Master.WorkerConnection

  alias Skitter.Runtime.ConstantStore
  require Skitter.Runtime.ConstantStore

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def init(ref) do
    unless Config.get(:mode, :local) == :local, do: WorkerConnection.subscribe_up()
    {:ok, ref}
  end

  def handle_info({:worker_up, node, _}, ref) do
    deployment = ConstantStore.get_all(:skitter_deployment, ref)
    links = ConstantStore.get_all(:skitter_links, ref)

    Remote.on(node, fn ->
      ConstantStore.put(deployment, :skitter_deployment, ref)
      ConstantStore.put(links, :skitter_links, ref)
      Runtime.Deployer.store_local_supervisors(ref, length(links))
    end)

    {:noreply, ref}
  end
end
