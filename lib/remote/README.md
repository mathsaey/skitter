# Remote

The code in this directory deals with connecting with other Skitter runtimes.
Two Skitter runtimes which connect with one another do so in two steps:

## Beacon

First, both runtimes ensure they are talking to a remote Skitter runtime and
figure out the mode of the remote runtime. This is handled by the `beacon`
module.

## Handler

Once connected, the exact behaviour of the runtimes depend on their mode and
the mode of their remote counterpart. The `handler` behaviour module defines
a behaviour which is used to create handler modules. Each mode defines its own
handlers and starts the remote supervisor which will ensure the correct handlers
are called at the appropriate times.

Handlers are defined in the `lib/mode` directory.
