# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Operation, only: :macros

defoperation Skitter.BIO.KeyedReduce, in: _, out: _, strategy: Skitter.BIS.KeyedState do
  @operationdoc """
  Keyed Reduce operation.

  This operation implements a reduce operation. It accepts three arguments wrapped in a tuple when
  embedded inside a workflow: a key function, a reduce function and an initial state. When this
  operation receives data, the key function is called with the received data as its first
  argument. The key function should return a key, which is used to obtain the state associated
  with the key. Afterwards, the reduce function is called with the received data as its first
  argument and the state associated with the key returned by the key function as its second
  argument. This function should return a `{state, emit}` tuple. The first value of this tuple
  will be stored as the new state of the key, while the second value of this tuple will be emitted
  on the `_` out port.
  """
  defcb init({_, _, initial_state}), do: state <~ initial_state
  defcb conf({key_fn, red_fn, _}), do: {key_fn, red_fn}

  defcb key(val) do
    {key_fn, _} = config()
    key_fn.(val)
  end

  defcb react(val) do
    {_, red_fn} = config()
    {new_state, emit} = red_fn.(val, state())
    state <~ new_state
    emit ~> _
  end
end
