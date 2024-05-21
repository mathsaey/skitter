# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.KeyedState do
  @moduledoc """
  Strategy for stateful operations that can partition their state by key.

  This strategy can be used for stateful operations with a keyed state. It expects an operation to
  provided a `key` and a `react` callback. When the operation receives data, the `key` callback
  will be called to determine the key of the incoming data, afterwards, the value will be sent to
  a worker maintaining the state for key. This worker might live on another cluster node. Finally,
  this worker will call the `react` callback to update the state of the key.

  ## Operation Properties

  * in ports: A single in port is required.
  * out ports: This strategy places no limitations on the out ports of the operation.
  * callbacks:
    * `key` (required): Called for each incoming data element. Can not access operation state.
    * `react` (required): Called for each incoming data element.
    * `conf` (optional): Called to create a configuration for the operation.
    * `initial_state` (optional): Called to create the initial state for a key when it occurs for
      the first time. If it is not provided, the state defaults to `nil`.
  """
  defhook deploy(args) do
    config = call_if_exists(:conf, args: [args]).result

    aggregators =
      Remote.on_all_worker_cores(fn -> local_worker(Map.new(), :aggregator) end)
      |> Enum.flat_map(fn {_node, workers} -> workers end)
      |> List.to_tuple()

    {config, aggregators}
  end

  defhook deliver(data) do
    {config, aggregators} = deployment()
    key = call(:key, config: config, args: [data]).result
    idx = rem(Murmur.hash_x86_32(key), tuple_size(aggregators))
    worker = elem(aggregators, idx)
    send(worker, data)
  end

  defhook process(data, state_map, :aggregator) do
    {config, _} = deployment()
    key = call(:key, config: config, args: [data]).result
    state = Map.get_lazy(state_map, key, fn -> initial_state(config) end)
    res = call(:react, state: state, config: config, args: [data])
    emit(res.emit)
    Map.put(state_map, key, res.state)
  end
end
