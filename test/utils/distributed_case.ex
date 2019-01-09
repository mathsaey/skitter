# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Test.DistributedCase do
  use ExUnit.CaseTemplate

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
