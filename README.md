![skitter logo](assets/logo_header.png)

[ [Homepage](https://soft.vub.ac.be/~mathsaey/skitter/) ]
[ [Documentation](https://soft.vub.ac.be/~mathsaey/skitter/docs/latest/readme.html) ]

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

We provide a brief introduction to creating and running Skitter projects below.
For more detailed information, we recommend browsing the
[docs](https://soft.vub.ac.be/~mathsaey/skitter/docs/latest/).
There, you can find detailed documentation on the language abstractions offered
by Skitter along with guides detailing how to deploy Skitter applications over
a cluster and how to configure them.

## Creating a new Skitter project

Skitter applications can be created in two ways: users can use the
`mix skitter.new` task to quickly create an initial Skitter application or they
can create a new Elixir project and add Skitter as a dependency.
Both of these options require the use of
[mix](https://hexdocs.pm/mix/Mix.html), the Elixir build tool.
We recommend the use of `mix skitter.new`.

### `mix skitter.new` (recommended)

`mix skitter.new` is a mix task which generates a basic Skitter application
which can then be modified to suit your needs. In order to use this task,
it should be installed on your system:

```
$ wget soft.vub.ac.be/~mathsaey/skitter/skitter_new.ez
$ mix archive.install skitter_new.ez
```

The first command downloads a compiled version of the task, while the second
adds the task to your local `mix` installation.

Once installed, `mix skitter.new <project_name>` can be used to create a new
Skitter project.
`<project_name>` should consist of lower case characters, spaces should be
replaced by underscores.
The generated project will contain a `README.md` file with information about
the generated code and instructions on how to run the Skitter application.
Furthermore, some example code will be present in `lib/project_name.ex` to help
you get started.

### Manual setup

To add Skitter to an exsiting project, you need to add it as a dependency and
configure the release of your application to use Skitter.
Skitter can be added as a project dependency by adding the following to your
`mix.exs` file:

```elixir
  {:skitter, github: "mathsaey/skitter"}
```

To configure the release of your application, set up a release (see
`mix release`) and follow the steps outlined in `Skitter.Release`.
Finally, it is recommended releases are built in production mode.

## Running the Project

A mix project can be started by using `iex -S mix`. This will start `iex`, the
interactive Elixir shell and load the current project.
`mix` will ensure that the Sktter runtime is started.

To deploy a workflow (if the application was created using `mix skitter.new` an
function which returns an example workflow will be present in
`lib/<project_name>.ex`), `Skitter.deploy/1` should be called.
This function will deploy a workflow, after which it can receive and process
data.

Note that, in the above explanation, the Skitter runtime is working in _local_
mode: it is acting as both a master and a worker runtime at the same time.
This mode is generally used for development, but not suited to deploy an
application over a cluster.
Please go to the
[deployment page of the documentation](https://soft.vub.ac.be/~mathsaey/skitter/docs/latest/deployment.html)
for information on how an application can be distributed over a cluster.
