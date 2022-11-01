# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    # Logger
    info: :*,
    debug: :*,
    warn: :*,
    error: :*,
    # Skitter DSL
    defoperation: :*,
    defcb: 2,
    state_struct: 1,
    initial_state: 1,
    defstrategy: :*,
    defhook: 2,
    workflow: :*,
    # Skitter config
    config_from_env: :*,
    config_enabled_if_set: :*,
    config_enabled_unless_set: :*
  ],
  export: [
    locals_without_parens: [
      defoperation: :*,
      defcb: :*,
      initial_state: 1,
      state_struct: 1,
      defstrategy: :*,
      defhook: 2,
      workflow: :*
    ]
  ]
]
