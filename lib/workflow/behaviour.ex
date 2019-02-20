# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.Behaviour do
  @moduledoc false

  alias Skitter.Workflow, as: W

  @callback __skitter_metadata__ :: W.Metadata.t()
  @callback __skitter_links__ :: %{required(W.address()) => [W.port_address()]}

  @callback __skitter_instances__ :: %{
    required(W.instance_identifier()) => [W.instance()]
  }
end
