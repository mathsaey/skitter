# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.BatchSource, out: _, strategy: Skitter.BIS.ActiveSource do
  @componentdoc """
  Source which produces a set of predefined data.

  This component is a source which is created with a set of data (an Elixir `Enumerable`). Once
  deployed, it will emit each element in the enumerable in order.
  """
  defcb init(enum), do: state <~ enum

  defcb produce do
    case state() |> Stream.take(1) |> Enum.to_list() do
      [] ->
        :stop
      [el] ->
        el ~> _
        state <~ Stream.drop(state(), 1)
    end
  end
end
