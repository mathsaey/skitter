# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.Instance do
  @moduledoc false

  defstruct [:mod, :ref]

  @type t :: %__MODULE__{
    mod: module(),
    ref: any()
  }

  @callback load(Skitter.Component.t(), any()) :: t()
  @callback react(t(), [any(), ...]) :: {:ok, pid(), reference()}

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
    end
  end

  defmacro create_instance(ref) do
    quote do
      %unquote(__MODULE__){mod: __MODULE__, ref: unquote(ref)}
    end
  end

  defmacro instance_ref() do
    quote do
      %unquote(__MODULE__){ref: var!(instance_ref)}
    end
  end
end

