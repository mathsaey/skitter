# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.FlatMap, in: _, out: _, strategy: Skitter.BIS.ImmutableLocal do
  @componentdoc """
  FlatMap component.

  This component implements a flatmap. When embedded inside a workflow, this component is provided
  with a function argument. This function will be called to process every element received by the
  component. This function should return a list. Each element in this list will be emitted on the
  `_` out port.
  """
  defcb conf(func), do: func
  defcb react(arg), do: config().(arg) ~>> _
end
