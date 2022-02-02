# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.KeyedState do
  @moduledoc """
  Strategy for stateful components that can partition their state by key.

  This strategy can be used for stateful components with a keyed state. It expects a component to
  provided a `key` and a `react` callback. When the component receives data, the `key` callback
  will be called to determine the key of the incoming data, afterwards, the value will be sent to
  a worker maintaining the state for key. This worker might live on another cluster node. Finally,
  this worker will call the `react` callback to update the state of the key.

  ## Component Properties

  * in ports: A single in port is required.
  * out ports: This strategy places no limitations on the out ports of the component.
  * callbacks:
    * `key` (required): Called for each incoming data element. Can not access component state. The
      invocation is passed to this callback as its second argument.
    * `react` (required): Called for each incoming data element.
    * `init` (optional): Called to create an initial state for a key.
    * `conf` (optional): Called to create a configuration for the component.
  """
  defhook deploy do
    config = call_if_exists(:conf, [args()]).result

    aggregators =
      Remote.on_all_worker_cores(fn -> local_worker(Map.new(), :aggregator) end)
      |> Enum.flat_map(fn {_node, workers} -> workers end)
      |> List.to_tuple()

    {config, aggregators}
  end

  defhook deliver(data, _port) do
    {_, aggregators} = deployment()
    key = call(:key, [data, invocation()]).result
    idx = rem(Murmur.hash_x86_32(key), tuple_size(aggregators))
    worker = elem(aggregators, idx)
    send(worker, data)
  end

  defhook process(data, state_map, :aggregator) do
    {config, _} = deployment()
    key = call(:key, [data, invocation()]).result
    state = Map.get_lazy(state_map, key, fn -> call_if_exists(:init, [args()]).state end)
    res = call(:react, state, config, [data])
    state_map = Map.put(state_map, key, res.state)
    [state: state_map, emit: res.emit]
  end
end
