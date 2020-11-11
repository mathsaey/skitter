# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.Handler do
  @moduledoc """
  Dummy handler for the use in unit tests.

  This handler will reject any remote with mode `:reject` and accept any other remote.
  """
  use Skitter.Remote.Handler
  alias Skitter.Remote

  def setup(mode, default_handler \\ __MODULE__) do
    Remote.set_local_mode(mode)
    Remote.setup_handlers(default: default_handler)
  end

  @impl true
  def init(), do: MapSet.new()

  @impl true
  def accept_connection(_, :reject, ms), do: {:error, :rejected, ms}
  def accept_connection(node, _, ms), do: {:ok, MapSet.put(ms, node)}

  @impl true
  def remove_connection(node, ms), do: MapSet.delete(ms, node)

  @impl true
  def remote_down(node, ms), do: MapSet.delete(ms, node)
end
