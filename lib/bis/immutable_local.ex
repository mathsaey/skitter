# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.ImmutableLocal do
  @moduledoc """
  Strategy for stateless components.

  This strategy can be used for stateless components. It expects a component to provide a `react`
  callback. When the component receives data, a worker on the current worker node is selected.
  The selected worker will call the react callback with the received data.

  ## Component Properties

  * in ports: A single in port is required.
  * out ports: This strategy places no limitations on the out ports of the component.
  * callbacks:
    * `react` (required): Called for each incoming data element.
    * `init` (optional): Called at deployment time. The resulting state will be passed to each
    invocation of `react`.
  """
  defhook deploy(args) do
    Nodes.on_all_worker_cores(fn ->
      create_worker(fn -> init_or_initial_state([args]) end, :worker, :local)
    end)
    |> Map.new()
  end

  defhook send(msg, _), do: send(Enum.random(deployment()[Nodes.self()]), msg)

  defhook receive(msg, state, :worker) do
    [emit: call_component(:react, state, [msg]).emit]
  end
end
