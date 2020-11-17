# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Compile-time configuration for the skitter_worker application.

import Config

import_config "../../../config/config.exs"

config :skitter_remote, mode: :worker
config :skitter_remote, :handlers, master: Skitter.Worker.MasterConnection
