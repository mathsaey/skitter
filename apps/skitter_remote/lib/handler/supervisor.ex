# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Handler.Supervisor do
  @moduledoc false
  use Supervisor

  alias Skitter.Remote.Handler

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    handlers =
      :skitter_remote
      |> Application.fetch_env!(:handlers)
      |> Enum.map(fn {mode, mod} -> {Handler.Server, [mod, mode]} end)

    Supervisor.init([Handler.Dispatcher | handlers], strategy: :rest_for_one)
  end
end
