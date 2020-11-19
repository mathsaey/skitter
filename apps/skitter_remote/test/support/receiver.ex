# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.Receiver do
  @moduledoc """
  Support for testing the dispatcher module.

  This module can accept requests from a dispatcher. It registers itself with the local
  `Skitter.Remote.Dispatcher` on start. The argument passed to `start_link/1` determines the mode.
  When `:default` is used, the receiver will register itself as the fallback case.
  """
  use GenServer
  alias Skitter.Remote.Handler.Dispatcher

  def start_link(mode) do
    GenServer.start_link(__MODULE__, mode)
  end

  def init(:default) do
    Dispatcher.default_bind()
    {:ok, nil}
  end

  def init(mode) do
    Dispatcher.bind(mode)
    {:ok, nil}
  end

  def handle_cast({:dispatch, _, from, _}, nil) do
    GenServer.reply(from, :ok)
    {:noreply, nil}
  end
end
