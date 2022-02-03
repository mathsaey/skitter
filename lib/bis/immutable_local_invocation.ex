# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.ImmutableLocalInvocation, extends: Skitter.BIS.ImmutableLocal do
  @moduledoc """
  Strategy for stateless components which modify the invocation.

  This strategy enables components to modify the invocation of received data element. It expects a
  `update_invocation` callback, which accepts the invocation of the received data element as its
  first argument and  the data element as its second argument. This callback should return a
  modified invocation, which will be used as the invocation of the emitted output. The received
  data will remain unchanged.

  ## Component Properties

  * in ports: A single in port is required.
  * out ports: A single out port is required.
  * callbacks:
    * `update_invocation` (required): Called for each incoming data element
    * `conf` (optional): Called at deployment time. The result will be passed as config to each
      call of `update_invocation`.
  """

  defhook process(msg, conf, :worker) do
    new_invocation = call(:update_invocation, conf, [invocation(), msg]).result
    emit(to_port(0, [msg]), new_invocation)
    conf
  end
end
