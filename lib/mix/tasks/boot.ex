# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Boot do
  @moduledoc """
  Skitter bootup functionality.

  This module collects the code which is used by the various mix tasks which
  start Skitter in a given mode.
  """
  def boot(mode) do
    Application.put_env(:skitter, :mode, mode, persistent: true)
    start_with_default_name(mode)
    Mix.Tasks.Run.run(args())
  end

  defp start_with_default_name(mode) do
    unless Node.alive?(), do: Node.start(mode, :shortnames)
  end

  defp args do
    args_no_halt()
  end

  defp args_no_halt do
    if Code.ensure_loaded(IEx) && IEx.started?() do
      []
    else
      ["--no-halt"]
    end
  end
end
