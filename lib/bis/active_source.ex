# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.ActiveSource do
  @moduledoc """
  Strategy for active source components.

  This strategy can be used to create a source component. It is designed for components that
  independently produce data to send into the workflow.

  When the component is deployed, the strategy will spawn a single worker and call the components
  `init` callback. Afterwards, the strategy will call the components `produce` callback, which is
  responsible for producing data. The strategy will keep on calling this callback until it returns
  `:stop`.

  ## Component Properties

  * in ports: none
  * out ports: This strategy places no limitations on the out ports of the component.
  * callbacks:
    * `init` (optional): Called at deployment time with the workflow arguments. The returned state
      is passed to `produce` callback, the returned value is passed as the configuration.
    * `produce` (required): Called in a loop to produce data. The emitted data is emitted by the
      strategy. When this callback returns `:stop`, the strategy will stop calling the `:produce`
      callback.
  """
  defhook deploy do
    remote_worker(
      fn ->
        send(self(), :tick, Invocation.meta())
        res = call_if_exists(:init, [args()])
        {res.state, res.result}
      end,
      :source
    )
    Remote.on_all_workers(fn -> local_worker(nil, :sender) end) |> Enum.map(&elem(&1, 1))
  end

  defhook process(:tick, {state, conf}, :source) do
    res = call(:produce, state, conf, [])
    send(Enum.random(deployment()), {:emit, res.emit})
    unless(res.result == :stop, do: send(self(), :tick))
    [state: {res.state, conf}]
  end

  defhook process({:emit, emit}, _, :sender) do
    [emit_invocation: Invocation.wrap(emit)]
  end
end
