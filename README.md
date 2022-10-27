![skitter logo](assets/logo_header.png)

[ [Homepage](https://soft.vub.ac.be/~mathsaey/skitter/) ]
[ [Documentation](https://hexdocs.pm/skitter/) ]

A domain specific language for building scalable, distributed stream processing
applications with custom distribution strategies.

Built in the context of my PhD at the
[Software Languages Lab](https://soft.vub.ac.be/).

# Skitter

Skitter is a reactive workflow system: it makes it possible to define data
processing pipelines which respond to incoming data automatically by combining
_components_ into a _workflow_.

A key difference between Skitter and other related technologies is the notion
of a _distribution strategy_: components in a Skitter workflow specify a
strategy which defines how the component is distributed over a cluster at
runtime.
This enables developers to select the appropriate distribution strategy for a
component for a given situation.
Strategies can be implemented from scratch or built based on existing
strategies.

More information about Skitter can be found at:
https://soft.vub.ac.be/~mathsaey/skitter.

## Publications and previous versions

We published about Skitter at the following venues:

- [Skitter: A DSL for Distributed Reactive Workflows](https://soft.vub.ac.be/~mathsaey/papers/REBLS_2018-Skitter_A_DSL_for_Distributed_Reactive_Workflows.pdf) (REBLS, November 2018)

Note that the version of Skitter discussed in this paper differs significantly
from the current version.
Information on using this earlier version of Skitter can be found
[here](https://soft.vub.ac.be/~mathsaey/skitter/docs/v0.1.1/).

# Getting started

Skitter is developed as a DSL in [Elixir](https://elixir-lang.org/). Therefore,
Elixir is required to write and run Skitter applications.
To install Elixir, please refer to the
[official documentation](https://elixir-lang.org/install.html).

Skitter requires the following Erlang/OTP and Elixir versions.

| Elixir | OTP |
| ------ | --- |
| 1.14   | 25  |

We provide a brief introduction to creating and running Skitter projects below.
For more detailed information, we recommend browsing the
[docs](https://hexdocs.pm/skitter/).
There, you can find detailed documentation on the language abstractions offered
by Skitter along with guides detailing how to deploy Skitter applications over
a cluster and how to configure them.

## Creating a new Skitter project

We have created a [mix](https://hexdocs.pm/mix/Mix.html) task to help users
create a new Skitter project.
This task creates a new mix project, configures it to use Skitter and provides
initial example code to help you get started.
In order to use this task, you need to add it to your local `mix` installation
(mix is installed as a part of Elixir).
You can do this as follows:

```
$ mix archive.install hex skitter_new
```

Once installed, `mix skitter.new <project_name>` can be used to create a new
Skitter project.
`<project_name>` should consist of lower case characters, spaces should be
replaced by underscores.
The generated project will contain a `README.md` file with information about
the generated code and instructions on how to run the Skitter application.
Furthermore, some example code will be present in `lib/project_name.ex` to help
you get started.

## Running a project

A mix project can be started by using `iex -S mix`. This will start `iex`, the
interactive Elixir shell and load the current project.
`mix` will ensure that the Skitter runtime is started.

When a Skitter runtime is started using `iex -S mix`, it starts in the so
called _local_ mode.
In this mode, the runtime acts as both a master and a worker at the same time,
which is useful for development.
If you wish to test your application in a slightly more realistic setting,
`mix skitter.master` and `mix skitter.worker` can be used to simulate multiple
separate runtime on your local machine.
Please refer to the
[deployment documentation](https://soft.vub.ac.be/~mathsaey/skitter/docs/latest/deployment.html#content)
and the documentation of these tasks for more information.

[Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html) are used to deploy a
Skitter application over a cluster.
To deploy a skitter application over a cluster, build a release using
`mix release`, afterwards, the Skitter deploy script can be used to deploy
your application over the cluster.
Please run `./_release/bin/skitter help deploy` or refer to the
[deployment documentation](https://soft.vub.ac.be/~mathsaey/skitter/docs/latest/deployment.html#content)
for more information.
