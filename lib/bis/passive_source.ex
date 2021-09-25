# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.PassiveSource do
  @moduledoc """
  Strategy for reactive source components.

  This strategy can be used to create a source component. It is designed for components that
  send data into the workflow as a response to incoming data.

  When the component is deployed, the strategy will spawn a single worker and call the component's
  `subscribe` callback with the arguments provided in the workflow. This callback should ensure
  that messages are sent to the worker in response to external events. Any time a message is sent
  to the worker, the strategy will call the `process` callback of the component, the component
  should emit a (list of) data elements based on the received message.

  The strategy ensures that `process` is called on a random worker node, to evenly distribute the
  incoming data over the cluster.

  ## Component Properties

  * in ports: none
  * out ports: This strategy places no limitations on the out ports of the component.
  * callbacks:
    * `subscribe` (required): Called at deployment time with the workflow arguments. This callback
    should ensure the worker receives messages in response to event.
    * `process` (required): Called for each received message. This callback should emit the list
    of received data to its out port to push them into the workflow.
  """
  defhook deploy do
    remote_worker(fn -> call_component(:subscribe, [args()]) end, :source)
    Nodes.on_all_workers(fn -> local_worker(nil, :sender) end) |> Enum.map(&elem(&1, 1))
  end

  defhook receive(msg, _, :source) do
    send(Enum.random(deployment()), msg)
    []
  end

  defhook receive(msg, _, :sender) do
    [emit_invocation: Invocation.wrap(call_component(:process, [msg]).emit)]
  end
end
