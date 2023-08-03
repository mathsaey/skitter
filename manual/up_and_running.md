# Up and Running

## Creating a project

Once [installed](installation.html#skitter), `mix skitter.new <project name>`
can be used to create a new Skitter project. This task creates a new Elixir
project, configures it to use Skitter and provides some initial code to help
you get started.

We can run `mix skitter.new` from any directory to create a new Skitter project.
The generator expects a `snake_case` project name; i.e. words should be lower
cased and spaces should be replaced by underscores. For the purposes of this
guide, let's create a `hello_skitter` project:

```
$ mix skitter.new hello_skitter
```

> #### mix task documentation {:.tip}
>
> Mix tasks accept command line flags and options that may tweak their
> behaviour. To find out more, you can click on any `mix <task name>` block in
> these docs to read the task's documentation.
>
> For instance, you can click on `mix skitter.new` to learn more about its
> behaviour.

> #### Skitter without `mix skitter.new` {:.info}
>
> It is possible to add Skitter as a dependency to an existing Elixir project.
> However, we recommend the use of `mix skitter.new`, especially for new users.
>
> Users who wish to add Skitter to an exising project should add `:skitter` as
> a dependency and customize their [release configuration](`mix release`) as
> detailed in `Skitter.Release`.

The tool will create a project for us:

```text
* creating hello_skitter
* creating hello_skitter/lib
* creating hello_skitter/config
* creating hello_skitter/mix.exs
* creating hello_skitter/.formatter.exs
* creating hello_skitter/config/config.exs
* creating hello_skitter/lib/hello_skitter.ex
* creating hello_skitter/.gitignore
* creating hello_skitter/README.md
```


After which it will ask if it should fetch and compile the dependencies of the
project. Either reply `y`, or `cd` into the project directory and run `mix
deps.get` followed by `mix deps.compile`.

```text
Fetch and build dependencies? [Yn] y
* Running `mix deps.get` in hello_skitter
<snip...>
* Running `mix deps.compile` in hello_skitter
<snip...>

Generated skitter app

  Your skitter project has been created at `hello_skitter`.
  You can now start working on your Skitter application:

  $ cd hello_skitter
  $ iex -S mix

  For your convenience, the generated README.md file contains a
  summary of the generated files and a summary of elixir commands.
```

As the generator says, we can `cd` into the directory of the project:

```shell
$ cd hello_skitter
```

and execute the project in the elixir shell:

```shell
$ iex -S mix
```

This will start `iex`, the elixir shell and start the current mix project (i.e.
`hello_skitter`). The generator generated an example "word count" application
and configured Skitter to automatically deploy the application when started.
Therefore, starting the project will produce the following output:

```text
Erlang/OTP 25 [erts-13.2.2.1] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns] [dtrace]

[19:29:31.329][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in local mode
[19:29:31.343][info] Deploying &HelloSkitter.workflow/0
{"Hello", 1}
{"Skitter", 1}
{"Hello", 2}
{"World!", 1}
Interactive Elixir (1.15.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

To exit `iex`, press `Ctrl + c` twice.

You now have a working Skitter project. The project generator created a
`README.md` file in your project, which tells you about the various files it
generated. Comments are also present in the various generated files.

> #### Elixir project structure {:.info}
>
> If you are not familiar with the structure of mix projects, it may be a good
> idea to browse the README and the generated files to see how everything fits
> together. We provide a short summary here.
>
> * `mix.exs`: Configures how `mix`, the elixir build tool, runs and compiles
>   your application.
> * `config/config.exs`: Configures your application and its dependencies (e.g.
>   skitter, logger).
> * `lib/`: contains the code of your application. Any `.ex` file present in
>   this directory will be picked up by mix, compiled and included in your
>   project.

The following section of the Skitter manual introduces the concepts required to
write Skitter applications of your own. Before we end this guide, we briefly
discuss the various ways in which you can run a Skitter project.

## Running the project

The most common way to run an elixir application is to use `iex -S mix`. `iex`
loads the Elixir shell, `iex`, while `-S mix` tells it to start `mix`, the
Elixir build tool, which will load your Skitter project.

> #### iex {:.info}
>
> The [official documentation](`IEx`) contains tons of useful information on
> how to use `iex` and on how it can be customized.

If you wish to run your application without starting a shell, you can use
`mix run --no-halt`, which will start your mix project without starting `iex`.
As before, `Ctrl + c` can be used to exit your application.

```text
mix run --no-halt
[19:53:22.826][info] ⬡⬢⬡⬢ Skitter v0.6.4 started in local mode
[19:53:22.841][info] Deploying &HelloSkitter.workflow/0
{"World!", 1}
{"Skitter", 1}
{"Hello", 1}
{"Hello", 2}
```

### Simulating a distributed system

When the mix project is started (using `iex -S mix` or `mix run`), Skitter
automatically starts in its so-called _local_ mode. In this mode, Skitter
acts as both a coordinator and a runner for your distributed stream processing
application, which is useful for development.

Eventually, it becomes useful to simulate a distributed environment on your
local machine. This can done through the use of `mix skitter.worker` and
`mix skitter.master`. The former starts a worker node, which executes
computations to perform, while the latter starts a master node, which divides
work among the workers.

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
### master
```shell
[20:05:21.629][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in master mode
[20:05:21.631][info] Reachable at `master@silverlode`
[20:05:21.656][info] Connected to `worker@silverlode`, tags: []
[20:05:21.667][info] Deploying &HelloSkitter.workflow/0
```
### worker
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
### master
```shell
$ elixir --sname master -S mix skitter.master worker1@silverlode worker2@silverlode
[20:08:05.314][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in master mode
[20:08:05.316][info] Reachable at `master@silverlode`
[20:08:05.341][info] Connected to `worker2@silverlode`, tags: []
[20:08:05.342][info] Connected to `worker1@silverlode`, tags: []
[20:08:05.354][info] Deploying &HelloSkitter.workflow/0
```
### worker1
```shell
$ elixir --sname worker1 -S mix skitter.worker
[20:07:38.046][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[20:07:38.049][info] Reachable at `worker1@silverlode`
[20:08:05.342][info] Connected to master: `master@silverlode`
{"Hello", 2}
{"Hello", 1}
```
### worker2
```shell
$ elixir --sname worker2 -S mix skitter.worker
[20:07:50.918][info] ⬡⬢⬡⬢ Skitter v0.7.0 started in worker mode
[20:07:50.920][info] Reachable at `worker2@silverlode`
[20:08:05.342][info] Connected to master: `master@silverlode`
{"World!", 1}
{"Skitter", 1}
```
<!-- tabs-close -->

Once you have tested your application in this semi-distributed fashion, you can
deploy it over an actual cluster. Skitter uses releases for this purpose. To
learn more, please refer to the
[deployment documentation](deployment.html#iex-and-mix-during-development).
