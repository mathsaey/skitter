# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.ImmutableLocal do
  @moduledoc """
  Strategy for stateless operations.

  This strategy can be used for stateless operations. It expects an operation to provide a `react`
  callback. When the operation receives data, a worker on the current worker node is selected.
  The selected worker will call the react callback with the received data.

  ## Operation Properties

  * in ports: A single in port is required.
  * out ports: This strategy places no limitations on the out ports of the operation.
  * callbacks:
    * `react` (required): Called for each incoming data element.
    * `conf` (optional): Called at deployment time. The result will be passed as config to each
    invocation of `react`.
  """
  defhook deploy do
    Remote.on_all_worker_cores(fn ->
      local_worker(fn -> call_if_exists(:conf, [args()]).result end, :worker)
    end)
    |> Map.new()
  end

  defhook deliver(msg, _), do: send(Enum.random(deployment()[Remote.self()]), msg)

  defhook process(msg, conf, :worker) do
    emit(call(:react, conf, [msg]).emit)
    conf
  end
end
