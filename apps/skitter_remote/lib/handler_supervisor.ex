# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.HandlerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link([]) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_handlers(list) do
    Enum.each(list, fn {mode, mod} -> add_handler(mode, mod) end)
  end

  def add_handler(mode, callback_module) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Skitter.Remote.HandlerServer, [callback_module, mode]}
    )
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
