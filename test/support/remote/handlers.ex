# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.AcceptHandler do
  @moduledoc """
  Dummy handler for the use in unit tests.

  This handler will accept any remote.
  """
  use Skitter.Remote.Handler

  @impl true
  def accept_connection(_, _, _), do: {:ok, nil}

  @impl true
  def remove_connection(_, _), do: nil

  @impl true
  def remote_down(_, _), do: nil
end

defmodule Skitter.Remote.Test.RejectHandler do
  @moduledoc """
  Dummy handler for the use in unit tests.

  This handler will reject any remote.
  """
  use Skitter.Remote.Handler

  @impl true
  def accept_connection(_, _, _), do: {:error, :rejected, nil}

  @impl true
  def remove_connection(_, _), do: nil

  @impl true
  def remote_down(_, _), do: nil
end

defmodule Skitter.Remote.Test.MapSetHandler do
  @moduledoc """
  Dummy handler for the use in unit tests.

  This handler will accept any remote and store them in a MapSet.
  """
  use Skitter.Remote.Handler

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
