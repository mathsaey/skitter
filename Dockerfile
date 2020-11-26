# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ----- #
# Build #
# ----- #

FROM hexpm/elixir:1.11.1-erlang-23.1.1-alpine-3.12.0 AS build

WORKDIR /skitter

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

COPY rel rel
COPY lib lib

RUN mkdir /target
RUN mix release --path /target

# --- #
# Run #
# --- #

FROM alpine:3.12 AS app

RUN apk add --no-cache ncurses-libs

WORKDIR /skitter

RUN chown nobody:nobody /skitter
USER nobody:nobody

COPY --from=build --chown=nobody:nobody /target ./

ENTRYPOINT ["sh", "skitter"]
CMD ["help"]
