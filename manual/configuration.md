# Configuration

This page details how the Skitter runtime can be configured.

Skitter is configured through its `Application` environment. Elixir enables
developers to customize this environment at compile time through the use of the
`config/config.exs` file. This environment can also be configured before the
application is started by using the `config/runtime.exs` file. Both files are
described in the `Config` documentation; additional information can be found
in the `mix release` documentation.

Concretely this means that you can use both `config/config.exs` and
`config/release.exs` to configure the Skitter runtime system. Besides this, the
skitter tasks, `mix skitter.worker` and `mix skitter.master` accept command
line arguments (described in their documentation) which further configure
Skitter. Similarly, skitter releases started through the `skitter` script also
accept command line arguments which customize the Skitter runtime system.

## Modes

A Skitter runtime is always started in a _mode_. This mode determines the role
of the Skitter runtime in a cluster environment. The following modes are
supported:

* `:worker`: This runtime will perform computations for a master node.
* `:master`: This runtime is responsible for coordinating the various workers
in the cluster.
* `:local`: This runtime acts as both a worker and a master runtime at the same
time. This is used for developing Skitter applications.

When no mode is specified, a `:local` runtime is started.

The mode a Skitter runtime is in effects the configuration options it accepts.
For instance, a worker runtime may be configured with the name of a single
master runtime, while a master runtime is configured with the name of various
workers. Any configuration present in the application environment that does not
belong to the current mode is ignored.

The various utilities which start a Skitter runtime automatically set the mode
of the runtime. Therefore, you should **not** set the mode yourself. The
following table shows how to start all types of runtimes based on how you are
starting the Elixir system.

Mode | Using `iex` | Using `mix` | Using releases
---- | --------- | --------- | --------------
`:local` | `iex -S mix` | `mix run` | `skitter local`
`:worker` | `iex -S mix skitter.worker` | `mix skitter.worker` | `skitter worker`
`:master` | `iex -S mix skitter.master` | `mix skitter.master` | `skitter master`

## Shared Configuration

- `:deploy` Used in `:local` and `:master` mode. This key should be set to a
  0-arity function which should return a `t:Skitter.Workflow.t/0`.
  This workflow will be deployed after the Skitter runtime has started.
  - When using releases, a string can be passed to the `--deploy` flag. This
    string will be evaluated (using `Code.eval_string/3`). The resulting value
    should be a workflow, which will be deployed after the Skitter runtime has
    started.
  - When using `mix`, the `--deploy` flag can be used to pass a string to `mix
    skitter.master`, which will be used in the same way.

- Skitter logs various messages to `Logger`. These cannot be disabled through
  Skitter itself, however, the `Logger` can be configured to ignore Skitter
  messages or to prune them at compile time. A Skitter release logs its log
  messages to the console logger and to a file (`logger/<node_name>.log`). The
  settings passed to this file will mirror the settings of the console logger.
  Logging to this file may be disabled by passing the `--no-log` option to
  `skitter deploy`, `skitter master`, `skitter worker` or `skitter local`.

- `:banner`: Determines if the `⬡⬢⬡⬢ Skitter <version> (<mode>)` banner is
  printed when the runtime is started inside `iex`, defaults to `true` for non
  release versions.

- `:telemetry`: Skitter can optionally emit telemetry events through the use of
  the `telemetry` package. This option determines whether these events are
  emitted or not. If this option is set to `false` (the default), all telemetry
  code is purged at compile time. Therefore, this option can not be adjusted
  after compile time. Note that Skitter does not register any handlers for the
  emitted telemetry data. An overview of the events emitted by Skitter can be
  found on the [telemetry page](telemetry.html).

## Master Configuration

- `:workers`: A list of workers to which the master will attempt to connect. If
  connecting to any of these workers fail, the master will shut down with an
  error.
  - When using `mix skitter.master`, the worker names can be provided as
    arguments to the mix task.
  - When using releases, the worker names can be provided as arguments to the
    script. The worker names may also be passed to `skitter deploy`.

- `:shutdown_with_workers`: Determines if the master should shut down when _any_
  worker it is connected to shuts down. Defaults to false.
  - `mix skitter.worker`, `skitter master` and `skitter deploy` accept a
    `--shutdown-with-workers` flag which enables this behaviour.

## Worker Configuration

- `:master`: A master to connect to. After starting, the worker will attempt to
  connect to the master node. If the connection fails, the worker will log a
  warning but stays alive.

- `:shutdown_with_master`: Determines if the worker should shut down when the
  master it is connected to shuts down. Defaults to true.
  - `mix skitter.worker`, `skitter worker` and `skitter deploy` accept a
    `--no-shutdown-with-master` flag which disables this behaviour.

- `:tags`: A list of `t:Skitter.Nodes.tag/0` which will be added to the worker.
  - `mix skitter.worker` and `skitter worker` accept a `--tag` flag which can be
    used to add tags to a worker. `skitter deploy` uses a special notation for
    worker names, which can be used to add tags to workers.
