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
  # - The current skitter application will be restarted in the mode provided to
  #   the `using` statement (`using Skitter.Test.DistributedCase, mode: <mode>`)
  # - When the tests have finished, skitter will restart in local mode.
  use ExUnit.CaseTemplate
  @moduledoc false

  using options do
    mode = Keyword.get(options, :mode, :master)

    quote do
      @moduletag :distributed
      alias Skitter.Test.Cluster

      setup_all do
        Cluster.become(unquote(mode))
        on_exit fn -> Cluster.become(:local) end
      end
    end
  end
end
