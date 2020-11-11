# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnection do
  @moduledoc false
  require Logger

  alias Skitter.Worker.Config
  use Skitter.Remote.Handler

  def maybe_connect, do: maybe_connect(Config.get(:master))

  defp maybe_connect(nil), do: :ok
  defp maybe_connect(remote), do: connect(remote)

  def connect(remote) do
    case Skitter.Remote.connect(remote, :master) do
      {:ok, :master} ->
        :ok

      {:error, reason} ->
        Logger.info("Could not connect to `#{remote}`: #{reason}")
        {:error, reason}
    end
  end

  @impl true
  def accept_connection(remote, :master, nil) do
    Logger.info("Connected to master: `#{remote}`")
    {:ok, remote}
  end

  def accept_connection(remote, :master, remote), do: {:error, :already_connected, remote}
  def accept_connection(_remote, :master, other), do: {:error, :has_master, other}

  @impl true
  def remove_connection(remote, remote), do: nil

  @impl true
  def remote_down(remote, remote) do
    Logger.info("Master `#{remote}` disconnected")

    if Config.get(:shutdown_with_master, true) do
      Logger.info("Lost connection to master, shutting down...")
      System.stop()
    end
  end
end
