# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

use Mix.Config

# Load environment specific configuration
import_config "#{Mix.env()}.exs"

# We use a unified logging output for every skitter application.
config :logger, :console,
  format: "\n[$time][$level$levelpad] $message\n+> $metadata\n",
  metadata: [
    :registered_name,
    :pid
  ]
