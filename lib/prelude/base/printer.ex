# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Prelude.Base.Printer do
  @moduledoc """
  Print any input it receives.

  This component prints any value it receives. It is initialized with a single
  `label`, which is prepended to the output to be displayed.
  """
  @behaviour Skitter.Prelude

  @impl true
  def _load do
    import Skitter.Component

    defcomponent Printer, in: value, out: value do
      fields label

      init l do
        label <~ l
      end

      react value do
        IO.inspect(value, label: label)
        value ~> value
      end
    end
  end
end
