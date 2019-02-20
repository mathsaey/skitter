# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.Metadata do
  @moduledoc false
  @data [:name, :description, :in_ports]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          in_ports: [atom()],
        }

  @enforce_keys @data
  defstruct @data
end
