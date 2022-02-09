# Deployment

This page details how a Skitter system can be deployed over one or many
machines.

## Elixir, mix and releases

Elixir offers several ways to run applications: during development, developers
compile and run their applications using `mix`, the elixir build tool and
`iex`, the interactive elixir shell. In order to run an application in
production, _releases_ (`mix release`) are used.

Skitter follows this convention. `mix` and `iex` are used to run an application
during development, while releases are built and used to deploy the application
over a cluster.

## `iex` and `mix` during development

While writing an application, developers typically use `iex` to experiment with
their application. Calling `iex -S mix` starts the interactive elixir shell and
loads the current project into `iex`, enabling users to access the modules of
their project and its dependencies. `mix run` can be used to start the project
without starting an interactive shell.

When a Skitter application (i.e. an application which uses Skitter as a
dependency) is started using `iex -S mix` or `mix run`, Skitter will start in
_local_ mode. In this mode, the Skitter runtime system will act as both a
master and a worker runtime, enabling developers to experiment with their code
in a single `iex` or `mix` session.

It is also possible to set up a local distributed environment for
experimentation. This is done by starting several Skitter runtimes; one of
these should be used as the master node, while other should be used as worker
nodes. `mix skitter.master` (or `iex -S mix skitter.master`) can be used to
start a Skitter master runtime, while `mix skitter.worker` (or
`iex -S mix skitter.worker`) can be used to start a worker runtime. In order to
connect these runtimes to each other, the right `--sname` flags need to be
passed. Please refer to the `mix skitter.worker` and `mix skitter.master`
documentation for more information.

## Releases

In order to deploy a Skitter over a cluster releases (`mix release`) are used.
This is done for several reasons:

- Releases are self-contained. This makes it easier to deploy an application
  along with the Skitter runtime and its dependencies over a cluster.
- Releases are somewhat optimized: unused modules are pruned and modules are
  preload when the erlang vm is started.
- Releases built with `Skitter.Release.step/1` include Skitter-specific
  configuration and scripts used to facilitate the distribution of a Skitter
  application over a cluster.

In order to enjoy this last benefit, Skitter should be able to customize the
generated release, this is done by adding `Skitter.Release.step/1` to the
`:steps` used to build a release. This is the case when your Skitter project
was created with `mix skitter.new`. Please refer to the `Skitter.Release`
module documentation for information on how to enable this if this is not the
case. Furthermore, releases should be built in `:prod` mode. Once again, this
is already the case when your project was created with `mix skitter.new`.

### The `skitter` deploy script

Releases customized by `Skitter.Release.step/1` include a `skitter` script in
the `<path_to_release>/bin/` directory. This script can be used to start a
standalone Skitter runtime or to deploy various Skitter runtimes over a
cluster. The following commands are supported:

Command | Shorthand | Description
------- | --------- | -----------
`deploy` | `d` | Deploy a Skitter system over a set of nodes
`local` | `l` | Manage a local Skitter runtime
`worker` | `w` | Manage a Skitter worker runtime
`master` | `m` | Manage a Skitter master runtime
`help` | `h` | Get help for a given command
`--application-version` | `-a` | the version of the release application
`--skitter-version` | `-v` | Get the version of skitter included with this release

Please run `<path_to_release>/bin/skitter help` for more information.

### Deploying an application over a cluster

The deploy mode of the Skitter deploy script can be used to deploy an
application over a cluster. At its simplest, the script can be called as
follows:

```
$ <path_to_release>/bin/skitter deploy <worker_host_1> <worker_host_2> … <worker_host_n>
```

This will spawn a Skitter worker runtime on each of the provided hosts, after
which a master is spawned on the local node. The master will connect to the
spawned workers. When the master quits, all the workers will quit as well. If
any of the workers cannot be spawned, the deploy script stops the created
workers and exits with an error.

The deploy script makes the following assumptions:

- The worker hosts are reachable over `ssh` without the need for a password
- The release is available at the same location on all worker nodes.
  - By default, it is assumed this location is the same as the directory from
    which the release was started. When this is not the case, the
    `--working-dir` option can be used. Use `skitter help deploy` for more
    information.

#### Starting a workflow

The skitter deploy script does not deploy any workflows over the cluster by
default, it only spawns master and worker runtimes and connects them together.
In order to start a workflow, a few options are available (ordered from most to
least preferable):

- Setting the `deploy:` key of the Skitter application environment to a
  0-arity function. The workflow returned by calling this function will be
  deployed over the cluster by Skitter. This option is automatically set in
  `config/config.exs` if `mix skitter.new` was used to create the application.
- Passing the `--deploy <expression>` flag to the deploy script. This will cause
  Skitter to deploy the workflow returned by evaluating `<expression>` over the
  cluster.
- Using `--mode start_iex` to start an interactive shell on the master node,
  which can be used to call `Skitter.Runtime.deploy/1`.
