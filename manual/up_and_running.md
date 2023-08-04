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
generated. Comments are also present in the various generated files. The
following section of the Skitter manual introduces the concepts required to
write Skitter applications of your own. Before we end this guide, we briefly
discuss the various ways in which you can run a Skitter project and the
structure of an Elixir project.

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

Once you have a working application, you can run it on a cluster computer.
Skitter supports executing your application on a cluster (i.e. on several
computers) and also enables the simulation of a distributed system on a single
machine. Please refer to the [deployment documentation](deployment.html) for
more information about both of these topics.

## Elixir project structure

`mix skitter.new` generates a `README.md` file which documents the overall
structure of the application it generated. We recommend reading this README and
browsing the generated files to see how everything fits together. We provide a
short summary of the most important files and directories in the project below:

If you are not familiar with the structure of mix projects, it may be a good
idea to browse the README and the generated files to see how everything fits
together. We provide a short summary here.
* `mix.exs`: Configures how `mix`, the elixir build tool, runs and compiles
  your application.
* `config/config.exs`: Configures your application and its dependencies (e.g.
  skitter, logger).
* `lib/`: contains the code of your application. Any `.ex` file present in
  this directory will be picked up by mix, compiled and included in your
  project.
