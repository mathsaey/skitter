# Configuration

Skitter aims to be usable out of the box without any additional configuration.
Running the Skitter deploy script with the appropriate options should be enough
to deploy a stream processing application over a cluster. Nevertheless, it may
be needed to tweak the behavior of Skitter. This page details the various
configuration options Skitter offers to modify its behavior.

> #### Configuring Elixir applications {:.tip}
>
> Elixir offers several options to configure the behavior of an application.
> This can sometimes make it difficult to figure out where configuration should
> go. The following list provides a quick overview of the various ways in which
> an application can be configured.
>
> * `config/config.exs`: compile-time configuration, created by default by
>    `mix skitter.new`. See `Config` for more information.
> * `config/runtime.exs`: runtime configuration. Evaluated every time before
>    the application is started. Not created by `mix skitter.new`.
>
> Additionally, Skitter can be configured by passing command-line parameters to
> `mix skitter.worker`, `mix skitter.master`, `skitter worker`,
> `skitter master`, `skitter local` or `skitter deploy`.

A Skitter runtime is always started in a _mode_ (i.e., worker, master or local).
Some configuration options are only useful when Skitter is running in a certain
mode. Skitter ignores any configuration options which are not relevant for the
mode it is started in.

## deploy

> #### Summary {:.neutral}
>
> Deploy the specified workflow after starting Skitter.
>
> - _master_ or _local_ mode
> - Default: `nil`
> - `config/config.exs`: `config :skitter, deploy: <expression>`
> - `config/runtime.exs`: `config :skitter, deploy: <expression>`
> - `mix skitter.master  --deploy <expression>` or `mix skitter.master -d <expression>`
> - `skitter master  --deploy <expression>` or `skitter master -d <expression>`
> - `skitter deploy  --deploy <expression>` or `skitter deploy -d <expression>`

This configuration option is used to specify a workflow which will be deployed
over the cluster after the Skitter runtime has started. There are two ways to
configure this option:

- Setting the `deploy` option in `config/config.exs` or `config.runtime.exs` to
  a 0-arity function. This function should return a workflow which will be
  deployed by Skitter.
  - This is the case if the project was generated using `mix skitter.new`.
- An expression can be passed as an argument to the `--deploy` flag. This
  expression will be evaluated using `Code.eval_string/3`. The resulting value
  should be a workflow, which will be deployed after the Skitter runtime has
  started.

## telemetry

> #### Summary {:.neutral}
>
> Enable telemetry events.
>
> - All modes
> - Default: `false`
> - Must be set at compile-time
> - `config/config.exs`: `config :skitter, telemetry: <boolean>`

Skitter can optionally emit telemetry events through the use of the `telemetry`
package. This option determines whether these events are emitted or not. If
this option is set to `false` (the default), all telemetry code is purged at
compile time. Therefore, this option can *only* be adjusted in
`config/config.exs`. More information about telemetry can be found on the
[telemetry page](telemetry.html).

## workers

> #### Summary {:.neutral}
>
> A list of workers to which the master will attempt to connect.
>
> - _master_ mode
> - Default: `[]`
> - `mix skitter.master <worker name> <worker name>`
> - `skitter master <worker name> <worker name>`
> - `skitter master --worker-file <path>` or `skitter master -f <path>`
> - `skitter deploy <worker name> <worker name>`
> - `skitter deploy --worker-file <path>` or `skitter deploy -f <path>`

A list of workers to which the master will attempt to connect. If connecting to
any of these workers fail, the master will shut down with an error.

A path to a file may also be provided to `skitter master` or `skitter deploy`.
This file must contain a worker address on each line. These workers will be
added to the list of workers.

## shutdown_with_workers

> #### Summary {:.neutral}
>
> Shut down the master when any connected worker shuts down.
>
> - _master_ mode
> - Default: false
> - `skitter master --shutdown-with-workers`
> - `skitter deploy --shutdown-with-workers`

This option is useful to ensure a single crashed worker shuts down all
connected Skitter runtimes.

## master

> #### Summary {:.neutral}
>
> A master to connect to.
>
> - _worker_ mode
> - Default: `nil`
> - `mix skitter.worker <master>`
> - `skitter worker <master>`

After starting, the worker will attempt to connect to the master node. If the
connection fails, the worker will log a warning but stays alive.


## shutdown_with_workers

> #### Summary {:.neutral}
>
> Shut down the worker if the master it is connected to shuts down.
>
> - _worker_ mode
> - Default: `true`
> - ` mix skitter.worker --no-shutdown-with-master`
> - `skitter worker --no-shutdown-with-master`
> - `skitter deploy --no-shutdown-with-master`

## tags

> #### Summary {:.neutral}
>
> Add the specified tags to the worker
>
> - _worker_ mode
> - Default: `true`
> - `mix skitter.worker -t <tag name 1> -t <tag name 2>`
> - `skitter worker -t <tag name 1> -t <tag name 2>`
> - `skitter deploy --worker-file <path>` or `skitter deploy -f <path>`

A list of `t:Skitter.Remote.tag/0` which will be added to the worker.

The `--worker-file` provides a special notation which can be used to add tags
to workers.
