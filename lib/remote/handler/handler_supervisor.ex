# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Handler.HandlerSupervisor do
  @moduledoc false
  use Supervisor
  alias Skitter.Remote.Handler

  def start_link(handlers) do
    Supervisor.start_link(__MODULE__, handlers, name: __MODULE__)
  end

  @impl true
  def init(handlers) do
    handlers = Enum.map(handlers, fn {mode, mod} -> {Handler.Server, [mod, mode]} end)
    Supervisor.init(handlers, strategy: :one_for_one)
  end
end
