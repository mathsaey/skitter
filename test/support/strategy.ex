# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Strategy

defstrategy Dummy do
  defhook deploy(_), do: nil
  defhook send(_, _), do: nil
  defhook receive(_, _, _), do: {nil, []}
end
