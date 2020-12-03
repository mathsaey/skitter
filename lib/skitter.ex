# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter do
  @moduledoc """
  Interface to the Skitter system.
  """

  @ps_key :skitter_manager_mod

  @doc false
  def set_manager_module(mod), do: :persistent_term.put(@ps_key, mod)

  def deploy(wf = %Skitter.Workflow{}) do
    mod = :persistent_term.get(@ps_key)
    {:ok, pid} = mod.create(wf)
    %Skitter.Proxy{pid: pid, name: wf.name}
  end
end
