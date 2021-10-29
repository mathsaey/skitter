# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy, only: :macros

defstrategy Skitter.BIS.ImmutableLocalInvocation, extends: Skitter.BIS.ImmutableLocal do
  @moduledoc """
  Strategy for stateless components which modify the invocation.

  This strategy works like `Skitter.BIS.ImmutableLocal`, but enables components to modify the
  invocation of received data elements. Instead of exepecting a `react` callback, it expecteds a
  `react_with_invocation` callback, which accepts the current invocation as its first argument.
  The result value of this callback should be a possibly modified invocation, which will be added
  to the emitted output values.

  ## Component Properties

  * in ports: A single in port is required.
  * out ports: This strategy places no limitations on the out ports of the component.
  * callbacks:
    * `react_with_invocation` (required): Called for each incoming data element.
    * `conf` (optional): Called at deployment time. The result will be passed as config to each
    invocation of `react`.
  """

  defhook receive(msg, conf, :worker) do
    res = call(:react_with_invocation, conf, [invocation(), msg])
    emit = map_emit(res.emit, &{&1, res.result})
    [emit_invocation: emit]
  end
end
