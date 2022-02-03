# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.StreamSource do
  @moduledoc """
  Strategy for stream-based source components.

  This strategy can be used to create a source component. It is designed for components which
  generate a stream of data that is to be sent into the workflow.

  When the component is deployed, this strategy will spawn a single worker and call the components
  `stream` callback. This callback should return a stream. Once deployed, the elements of this
  stream will be emitted by one by one. The strategy ensures these values are shuffled over the
  available worker nodes.

  ## Component Properties

  * in ports: none
  * out ports: a single out port.
  * callbacks:
    * `stream`: Called at deployment time. This callback should return a stream, which will be
    emitted once the component has been deployed.
  """
  defhook deploy do
    remote_worker(
      fn ->
        send(self(), :start, Invocation.meta())
        call(:stream, [args()]).result
      end,
      :source
    )
    Remote.on_all_workers(fn -> local_worker(nil, :sender) end) |> Enum.map(&elem(&1, 1))
  end

  defhook process(:start, stream, :source) do
    stream
    |> Stream.each(&send(Enum.random(deployment()), {:emit, &1}))
    |> Stream.run()
  end

  defhook process({:emit, emit}, nil, :sender) do
    emit(to_port(0, [emit]), Invocation.new())
    nil
  end
end
