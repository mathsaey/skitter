![skitter logo](assets/logo_header.png)

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

## Installation

Skitter is developed as a DSL in [Elixir](https://elixir-lang.org/). Therefore,
Elixir should be installed to use Skitter. In order to install Elixir, please
refer to the [official documentation](https://elixir-lang.org/install.html).

Once Elixir is installed, Skitter can be used by creating a `mix` (the Elixir
build tool) project which includes Skitter as a dependency. We provide a `mix`
task which automates this process by creating a project with the required
dependencies and configuration. It can be installed as follows:

```
$ wget soft.vub.ac.be/~mathsaey/skitter/skitter_new.ez
$ mix archive.install skitter_new.ez
```

The first command downloads a compiled version of the installer, while the
second adds the command to your local `mix` installation. After installation,
`mix help skitter.new` can be used to verify if the installation of the package
was successful.

## Creating a Skitter project

Using the installer, a Skitter project can be created by using:

```
$ mix skitter.new <project_name>
```

`<project_name>` should consist of lower case characters, spaces should be
replaced by underscores.

The generated project will contain a `README.md` file with information about
the generated code and instructions on how to run the Skitter application.
Furthermore, some example code will be present in `lib/project_name.ex` to help
you get started.

## Running the Project

A mix project can be started by using `iex -S mix`. This will start `iex`, the
interactive Elixir shell, and load the current project (this is done by
providing the `-S mix` argument). Starting a project that uses Skitter as a
dependency this way will automatically start the Skitter runtime in _local_
mode, which causes it to act as both a _master_ and a _worker_ at the same
time. Local mode is generally used when developing applications.

Once the Skitter system is up and running, the workflow defined in
`lib/project_name.ex` can be _deployed_ by calling `Skitter.deploy/1`. This
will deploy the workflow, enabling it to receive and process data.

## Distributed Execution

It is useful to simulate the distributed execution of an application before
actually deploying it over a cluster. This can be done by using `mix
skitter.worker` and `mix skitter.master` on your local machine. Please refer to
their documentation (`mix help skitter.master` or `mix help skitter.worker`)
for more information.

We use [releases](https://hexdocs.pm/mix/master/Mix.Tasks.Release.html) to
deploy a complete skitter system over a cluster. Running `mix release` will
create a self-contained version of Elixir, Skitter and your application, which
can be stored on the various nodes of your cluster. Once this is done, the
provided `skitter` script can be used to deploy your application over the
cluster. Please use `./_release/bin/skitter help` for more information.
