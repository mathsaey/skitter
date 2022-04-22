# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros
alias Skitter.BIS.ImmutableLocal

defcomponent Skitter.BIC.Filter, in: _, out: [accept, reject], strategy: ImmutableLocal do
  @componentdoc """
  Filter component.

  This component implements a filter. When embedded inside a workflow, this component is provided
  with a function argument. This function will be called to process every element received by the
  component. If the function returns true, the received element will be sent to the `accept` port.
  Otherwise, the element will be sent to the `reject` out port.
  """

  defcb conf(func), do: func

  defcb react(val) do
    config()

    if config().(val) do
      val ~> accept
    else
      val ~> reject
    end
  end
end
