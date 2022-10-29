# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.PassiveSource do
  @moduledoc """
  Strategy for reactive source operations.

  This strategy can be used to create a source operation. It is designed for operations that
  send data into the workflow as a response to incoming data.

  When the operation is deployed, the strategy will spawn a single worker and call the operation's
  `subscribe` callback with the arguments provided in the workflow. This callback should ensure
  that messages are sent to the worker in response to external events. Any time a message is sent
  to the worker, the strategy will call the `process` callback of the operation, the operation
  should emit a (list of) data elements based on the received message.

  The strategy ensures that `process` is called on a random worker node, to evenly distribute the
  incoming data over the cluster.

  ## Operation Properties

  * in ports: none
  * out ports: This strategy places no limitations on the out ports of the operation.
  * callbacks:
    * `subscribe` (required): Called at deployment time with the workflow arguments. This callback
    should ensure the worker receives messages in response to event.
    * `process` (required): Called for each received message. This callback should emit the list
    of received data to its out port to push them into the workflow.
  """
  defhook deploy do
    remote_worker(fn -> call(:subscribe, [args()]) end, :source)
    Remote.on_all_workers(fn -> local_worker(nil, :sender) end) |> Enum.map(&elem(&1, 1))
  end

  defhook process(msg, nil, :source) do
    send(Enum.random(deployment()), msg)
    nil
  end

  defhook process(msg, nil, :sender) do
    emit(call(:process, [msg]).emit, &Invocation.new/0)
    nil
  end
end
