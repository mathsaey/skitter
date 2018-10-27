# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Metadata do
  @moduledoc false
  @data [:name, :description, :effects, :in_ports, :out_ports, :arity]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          effects: [keyword()],
          in_ports: [atom()],
          out_ports: [atom()],
          arity: pos_integer()
        }

  @enforce_keys @data
  defstruct @data
end
