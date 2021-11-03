# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.KeyedReduce, in: _, out: _, strategy: Skitter.BIS.KeyedState do
  @componentdoc """
  Keyed Reduce component.

  This component implements a reduce operation. It accepts two arguments when embedded inside a
  workflow: a function and an initial state. When this component receives data, the function is
  called with the received data as its first argument and the current state as the second
  argument. The function should then return a new state to be used by the next data element.

  The state of this componennt is grouped by key. The key that will be used is determined by a
  previous element in the workflow, such as the `Skitter.BIC.KeyBy` component. When no state is
  present for the key, the initial state passed as an argument to the component will be passed as
  the state.
  """

  defcb init({_, initial_state}), do: state <~ initial_state
  defcb conf({function, _}), do: function
  defcb key(_, inv), do: inv[:key]

  defcb react(tup) do
    state <~ config().(tup, state())
    state() ~> _
  end
end
