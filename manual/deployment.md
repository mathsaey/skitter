# Deployment

Once you have a working stream processing application, you may wish to test it
as a distributed system on your machine before distributing it over a cluster.
This guide documents how Skitter supports both of these scenarios.

> #### Elixir, mix and releases {:.info}
> Elixir offers several ways to run applications: during development,
> developers compile and run their applications using `mix`, the elixir build
> tool and `iex`, the interactive elixir shell. In order to run an application
> in production, _releases_ (`mix release`) are commonly used.
>
> Skitter follows this convention. `mix` and `iex` are used to run an application
> during development, while releases are built and used to deploy the application
> over a cluster.

## Development in local mode

While writing an application, developers typically use `iex` to experiment with
their application. Calling `iex -S mix` starts the interactive elixir shell and
loads the current project into `iex`, enabling users to access the modules of
their project and its dependencies. `mix run --no-halt` can be used to start
the project without starting an interactive shell.

When a Skitter application (i.e. an application which uses Skitter as a
dependency) is started using `iex -S mix` or `mix run`, Skitter will start in
its so-called _local_ mode. In this mode, Skitter acts as both a coordinator
and a runner for your distributed stream processing application, which is
useful for development.

## Simulating a distributed system

Eventually, it becomes useful to simulate a distributed environment on your
local machine. This can done through the use of `mix skitter.worker` and
`mix skitter.master`. The former starts a worker node, which executes
computations to perform, while the latter starts a master node, which divides
work among the workers. Setting up a working Skitter system requires one master
node and at least one worker node. Additionally, both nodes need to be
connected to one another.

In order to enable an Elixir node to connect to other nodes, it needs to be
provided with a name, this can be done through the use of the `--sname` option,
which can be passed to the `elixir` or the `iex` command. For instance, to
start a worker named `worker`:

<!-- tabs-open -->
### iex
```shell
iex --sname worker -S mix skitter.worker
```
### elixir
```shell
elixir --sname worker -S mix skitter.worker
```
<!-- tabs-close -->

Afterwards, you can start a master node in a different terminal window. You
need to provide the name of the worker node, suffixed with the hostname of your
computer to enable both to work together:

<!-- tabs-open -->
### iex
```shell
iex --sname master -S mix skitter.master worker@<hostname>
```
### elixir
```shell
elixir --sname master -S mix skitter.master worker@<your hostname here>
```
<!-- tabs-close -->

Once the master is connected to the worker, it will deploy its workflow.

<!-- tabs-open -->
### master output
```shell
[20:05:21.629][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in master mode
[20:05:21.631][info] Reachable at `master@silverlode`
[20:05:21.656][info] Connected to `worker@silverlode`, tags: []
[20:05:21.667][info] Deploying &HelloSkitter.workflow/0
```
### worker output
```shell
[20:05:04.573][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[20:05:04.575][info] Reachable at `worker@silverlode`
[20:05:21.656][info] Connected to master: `master@silverlode`
{"Skitter", 1}
{"Hello", 1}
{"Hello", 2}
{"World!", 1}
```
<!-- tabs-close -->

You can create as many worker nodes you like:

<!-- tabs-open -->
### master output
```shell
$ elixir --sname master -S mix skitter.master worker1@silverlode worker2@silverlode
[20:08:05.314][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in master mode
[20:08:05.316][info] Reachable at `master@silverlode`
[20:08:05.341][info] Connected to `worker2@silverlode`, tags: []
[20:08:05.342][info] Connected to `worker1@silverlode`, tags: []
[20:08:05.354][info] Deploying &HelloSkitter.workflow/0
```
### worker1 output
```shell
$ elixir --sname worker1 -S mix skitter.worker
[20:07:38.046][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[20:07:38.049][info] Reachable at `worker1@silverlode`
[20:08:05.342][info] Connected to master: `master@silverlode`
{"Hello", 2}
{"Hello", 1}
```
### worker2 output
```shell
$ elixir --sname worker2 -S mix skitter.worker
[20:07:50.918][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[20:07:50.920][info] Reachable at `worker2@silverlode`
[20:08:05.342][info] Connected to master: `master@silverlode`
{"World!", 1}
{"Skitter", 1}
```
<!-- tabs-close -->

## Deploying an application over a cluster

While `mix skitter.worker` and `mix skitter.master` could be used to distribute
an application over a cluster, Skitter instead uses _releases_ (`mix release`)
for this purpose. This is done for several reasons:

- Releases are self-contained. This makes it easier to deploy an application
  along with the Skitter runtime and its dependencies over a cluster.
- Releases are somewhat optimized: unused modules are pruned and modules are
  preload when the erlang vm is started.
- Releases include management scripts, including the skitter deploy script,
  which facilitates the distribution of a Skitter application over a cluster.

A Skitter application is thus deployed over a cluster by:

1. Compiling it into a release
2. Using the skitter deploy script to start the distributed system

### Creating a release

A release is simply created by running `mix release` at the root of your
project (i.e. in the directory that has the `mix.exs` file).

Using the `hello_skitter` project discussed in the
[up and running](up_and_running.html) guide, this looks as follows:

```shell
$ mix release
<mix compile output snipped>
* creating _release/releases/0.1.0/vm.args
* creating _release/releases/0.1.0/remote.vm.args
* creating _release/releases/0.1.0/env.sh
* creating _release/bin/skitter
```

The `_release` directory now contains a bunch of files which make up your
release. In this guide, we will mainly interact with the `_release/bin/skitter`
file, which is a script that is used to deploy your application over a cluster.

> #### Releases without `mix skitter.new` {:.info}
>
> `mix skitter.new` automatically configures the generated project for the easy
> generation of releases. If you did not use `mix skitter.new`, or if you need
> to adjust the project configuration for some other reasons, it is important
> to ensure skitter can still customize the generated release. This is done by
> adding `Skitter.Release.step/1` to the `:steps` used to build a release.
> Please refer to the `Skitter.Release` documentation for more information.
>
> Additionally, you should ensure your releases are built in `:prod` mode. Once
> again, this is the case when your project was created with `mix skitter.new`.

> #### Copying releases to other machines {:.info}
>
> Releases can be copied to other machines as long as the target machine runs
> the same operating system distribution as the machine which ran the
> `mix release` command. The target machine does not need to have Erlang/Elixir
> installed, as the Erlang and Elixir runtime system are bundled with the
> release.
>
> Thus, you can compile your release on the master node of a cluster and copy
> it over to the worker nodes.

### The skitter script

The `skitter` script stored in `_release/bin/` can be used to start a
standalone Skitter master or worker node, or to deploy several workers and a
single master of a cluster. The table below lists the supported commands; you
can get more information by running `_release/bin/skitter help`.

Command | Description
------- | -----------
`deploy` | Deploy a Skitter system over a set of nodes
`local` | Manage a local Skitter runtime
`worker` | Manage a Skitter worker runtime
`master` | Manage a Skitter master runtime
`help` | Get help for a given command
`--application-version` | Get the version of the release application
`--skitter-version` | Get the version of skitter included with this release

`./bin/skitter local`, `./bin/skitter worker` and `./bin/skitter master` can be
used to start local, worker or master runtimes respectively. Thus, you can
manually spawn a distributed system to test the release, similar to how it is
done with `mix`.

<!-- tabs-open -->
### master output
```shell
$ ./_release/bin/skitter master start worker1@silverlode worker2@silverlode
[17:39:08.833][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in master mode
[17:39:08.833][info] Reachable at `skitter_master@silverlode`
[17:39:08.997][info] Connected to `worker2@silverlode`, tags: []
[17:39:08.998][info] Connected to `worker1@silverlode`, tags: []
[17:39:08.999][info] Deploying &HelloSkitter.workflow/0
```
### worker1 output
```shell
$ ./_release/bin/skitter worker start --name worker1
[17:38:40.608][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[17:38:40.608][info] Reachable at `worker1@silverlode`
[17:39:08.999][info] Connected to master: `skitter_master@silverlode`
{"Hello", 1}
{"Hello", 2}
```
### worker2 output
```shell
$ ./_release/bin/skitter worker start --name worker2
[17:38:51.599][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[17:38:51.599][info] Reachable at `worker2@silverlode`
[17:39:08.997][info] Connected to master: `skitter_master@silverlode`
{"Skitter", 1}
{"World!", 1}
```
<!-- tabs-close -->

Please refer to the documentation returned by running
`./_release/bin/skitter help worker` and `./_release/bin/skitter help master`
for more information.

### skitter deploy

Manually spawning master and worker nodes on a potentially large cluster is
tedious. Therefore, the skitter script includes a `deploy` command, which deploys
an application over a cluster, starting the required worker and master nodes as
needed.

At its simplest, you provide the script with the hostnames of the various
worker machines of your cluster; the script will then ssh to each node and
start a worker. Once this is done, it will start a master node on the node
where the deploy script was run; the master node will attempt to connect to
every worker node.

On a cluster with three nodes named `isabelle-a`, `isabelle-b` and
`isabelle-c`, the output of the deploy script looks as follows when used
on the `hello_skitter` project.

```shell
$ ./_release/bin/skitter deploy isabelle-a isabelle-b isabelle-c
⬡⬢⬡⬢ Skitter deploy 0.7.0
> workers:  isabelle-a isabelle-b isabelle-c

* starting worker on isabelle-a ✓
* starting worker on isabelle-b ✓
* starting worker on isabelle-c ✓

⧖ sleeping 10 second(s) while workers start.
✓ finished deployment, starting master.
[20:58:29.950][info] ⬡⬢⬡⬢ Skitter v0.6.4 started in master mode
[20:58:29.950][info] Reachable at `skitter_master@isabelle`
[20:58:29.958][info] Connected to `skitter_worker@isabelle-a`, tags: []
[20:58:29.959][info] Connected to `skitter_worker@isabelle-c`, tags: []
[20:58:29.960][info] Connected to `skitter_worker@isabelle-b`, tags: []
[20:58:29.960][info] Deploying &HelloSkitter.workflow/0
```

When using the deploy script, the cluster is set up to ensure the worker
nodes quit if the master node quits. If any of the worker nodes cannot
be spawned, the deploy script stops the created workers and exits with
an error.

The behaviour of the script can be tweaked as needed; please run
`./_release/bin/skitter help deploy` for more information.

The deploy script makes the following assumptions:
- The worker hosts are reachable over `ssh` without the need for a password
- The release is available at the same location on all worker nodes.
  - By default, it is assumed this location is the same as the directory from
    which the release was started. When this is not the case, the
    `--working-dir` option can be used. See `skitter help deploy` for more
    information.
