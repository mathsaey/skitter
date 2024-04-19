# Copyright 2018 - 2023, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Token do
  alias Skitter.Operation

  @type t :: %__MODULE__{
          value: any(),
          port: Operation.port_name() | nil,
          meta: %{optional(atom()) => any()}
        }
  @enforce_keys [:value]
  defstruct value: nil, port: nil, meta: %{}

  def unwrap(%__MODULE__{value: v}), do: v
  def unwrap(v), do: v

  def wrap(t = %__MODULE__{}), do: t
  def wrap(v), do: %__MODULE__{value: v}
end
