# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runtime configuration of skitter releases. Anything in this file is executed
# after the ERTS is started, but before any skitter applications are loaded.

import Skitter.Runtime.Release

config_from_env :skitter_master, :workers, "SKITTER_WORKERS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end

config_from_env :skitter_worker, :master, "SKITTER_MASTER", &String.to_atom/1

config_enabled_unless_set :skitter_worker,
                          :shutdown_with_master,
                          "SKITTER_NO_SHUTDOWN_WITH_MASTER"
