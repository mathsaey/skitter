# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runtime configuration of the Skitter release.

import Skitter.Config

config_from_env :mode, "SKITTER_MODE", &String.to_atom/1

# Worker
# ------

config_from_env :master, "SKITTER_MASTER", &String.to_atom/1

config_enabled_unless_set :worker_shutdown_with_master, "SKITTER_NO_SHUTDOWN_WITH_MASTER"

# Master
# ------

config_from_env :workers, "SKITTER_WORKERS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end
