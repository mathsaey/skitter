# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Instance do
  @moduledoc false

  @enforce_keys [:state, :component]
  defstruct [:state, :component]

  @typep state :: [{atom(), any()}]

  @type t :: %__MODULE__{
          state: state(),
          component: Skitter.Component.t()
        }
end
