# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.TransientInstance.Server do
  @moduledoc false
  use Task, restart: :transient

  def start_link(args) do
    Task.start_link(__MODULE__, :react, [args])
  end

  def react({key, args, dst, ref}) do
    inst = :persistent_term.get(key)
    {:ok, _, spits} = Skitter.Component.react(inst, args)
    send(dst, {:react_finished, ref, spits})
  end
end
