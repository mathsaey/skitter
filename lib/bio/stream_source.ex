# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Operation, only: :macros

defoperation Skitter.BIO.StreamSource, out: _, strategy: Skitter.BIS.StreamSource do
  @operationdoc """
  Source which produces a stream of predefined data.

  This operation is a source which is created with a set of data (an Elixir `Enumerable`). Once
  deployed, it will emit each element in the enumerable in order.
  """
  defcb stream(stream), do: stream
end
