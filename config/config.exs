# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This file is responsible for the compile-time application environment configuration of the
# various Skitter applications. Note that, in Skitter, each child application is responsible for
# setting up its own application configuration. Thus, child-specific configuration can be found in
# `apps/<child name>/config/`, global configuration should happen here.
#
# There are three possible ways that this file could be loaded:
#   1. The umbrella project is built as a whole. In this case, child configuration is not loaded.
#   2. A child application is compiled individually and refers to this file in its `config_path`.
#   3. A child application with a custom configuration is compiled individually and uses
#      `Config.import_config/1` to load this file.

import Config

config :logger, :console,
  format: "\n[$time][$level$levelpad] $message",
  metadata: :all

import_config "#{Mix.env()}.exs"
