# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Operation, only: :macros

defoperation Skitter.BIO.Send, in: _, strategy: Skitter.BIS.ImmutableLocal do
  @operationdoc """
  Send operation.

  This operation is a sink that sends any data it receives to a given pid. The pid that should
  receive the messages should be provided as an argument when the operation is embedded inside a
  workflow.
  """
  defcb conf(pid), do: pid
  defcb react(val), do: send(config(), val)
end
