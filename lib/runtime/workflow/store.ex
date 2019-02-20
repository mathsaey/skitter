# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Store do
  @moduledoc false

  def put(ref, val) do
    :ok = :persistent_term.put(ref, val)
    ref
  end

  def get(key), do: :persistent_term.get(key)

  def get_links(key), do: get(key).links
  def get_workflow(key), do: get(key).workflow
  def get_instances(key), do: get(key).instances
end
