# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.Application do
  @moduledoc false
  require Logger

  use Application
  use Skitter.Application

  def start(:normal, []) do
    noninteractive_skitter_app()

    Skitter.Worker.MasterConnection.maybe_connect()

    children = []
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
