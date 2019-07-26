# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Test.DistributedCase do
  # Case template for unit tests which test distributed functionality.
  #
  # Using this ExUnit case template will ensure that:
  # - Cluster is aliased
  # - The test case is automatically marked as distributed.
  # - When the tests have finished, skitter will restart in local mode.
  use ExUnit.CaseTemplate
  @moduledoc false

  using _ do
    quote do
      @moduletag :distributed
      alias Skitter.Test.Cluster

      setup_all do
        on_exit(&Cluster.load_default/0)
      end
    end
  end
end
