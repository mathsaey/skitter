# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runtime configuration of a skitter master release. Anything in this file is executed after the
# ERTS is started, but before any skitter applications are loaded.
#
# Skitter releases are configured through environment variables which are set by the skitter
# deployment script (`rel/skitter.sh.eex`)

import Skitter.Master.Config

config_from_env :workers, "SKITTER_WORKERS", fn str ->
  str |> String.split() |> Enum.map(&String.to_atom/1)
end
