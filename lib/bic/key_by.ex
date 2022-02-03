# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.KeyBy, in: _, out: _, strategy: Skitter.BIS.ImmutableLocalInvocation do
  @componentdoc """
  Determine the key of a data element.

  This component associates a key with each incoming data element. The key that is used is
  determined by a function passed as an argument to the component. This function will accept each
  incoming data element and return the key for this data element.
  """
  defcb conf(func), do: func
  defcb update_invocation(inv, val), do: Map.put(inv, :key, config().(val))
end
