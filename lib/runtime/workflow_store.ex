# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.WorkflowStore do
  @moduledoc false

  def put(w = %Skitter.Workflow{}) do
    key = make_ref()
    :persistent_term.put({__MODULE__, key}, w)
    key
  end

  def put(w = %Skitter.Workflow{}, key) do
    :persistent_term.put({__MODULE__, key}, w)
    :ok
  end

  def get(ref), do: :persistent_term.get({__MODULE__, ref})
  def erase(ref), do: :persistent_term.erase({__MODULE__, ref})
end
