# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Instance do
  @moduledoc false

  @data [:state, :component]

  @type t :: %__MODULE__{
          state: [{atom(), any()}],
          component: module()
        }

  @enforce_keys @data
  defstruct @data
end
