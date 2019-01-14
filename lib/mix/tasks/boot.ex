# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Boot do
  @moduledoc false

  import Skitter.Configuration

  def boot(mode, args \\ []) do
    put_env(:mode, mode)
    Mix.Tasks.Run.run(modify_args(args))
  end

  defp modify_args(args) do
    args ++ args_no_halt()
  end

  defp args_no_halt, do: if IEx.started?(), do: [], else: ["--no-halt"]
end
