# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.Instance do
  @moduledoc false
  defstruct [:mod, :ref]

  @type t :: %__MODULE__{mod: module(), ref: any()}
  @callback load(Skitter.Component.t(), any()) :: {:ok, t()}
  @callback react(t(), [any(), ...]) :: {:ok, pid(), reference()}
end

defimpl Inspect, for: Skitter.Runtime.Component.Instance do
  import Inspect.Algebra

  def inspect(inst, opts) do
    mod_last = inst.mod |> Module.split() |> List.last()
    container_doc(
      "#RuntimeComponentInstance[",
      [mod_last, inst.ref],
      "]",
      opts,
      fn el, opts -> to_doc(el, opts) end,
      separator: ","
    )
  end
end
