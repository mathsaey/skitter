# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Config

config :skitter,
  standard_library_path: Path.join(File.cwd!(), "stdlib")

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :warn]
  ]
