# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter do
  @moduledoc false

  def start(mode, config) do
    config |> Keyword.merge(mode: mode) |> put()
    Mix.Tasks.Run.run(if(IEx.started?(), do: [], else: ["--no-halt"]))
  end

  def put(lst) when is_list(lst), do: Enum.each(lst, &put/1)
  def put({k, v}), do: Skitter.Config.put(k, v)
end
