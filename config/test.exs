# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Config

# When testing from the umbrella application, application-local configuration is not loaded.
# Therefore, we set some application-specific configuration in this file.

config :skitter_remote, :mode, :test_mode
config :skitter_remote, :handlers, []

config :skitter_worker, :shutdown_with_master, false
