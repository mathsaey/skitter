# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Config

config :logger,
  default_formatter: [format: "[$time][$level]$metadata $message\n"],
  default_handler: [config: [type: :standard_error]]

import_config "#{Mix.env()}.exs"
