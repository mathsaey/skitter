![skitter logo](https://raw.githubusercontent.com/mathsaey/skitter/develop/assets/logo.png)

# Skitter

Skitter is a component agnostic, reactive workflow system.

Skitter makes it possible to wrap arbitrary data processing applications into
_reactive components_.
These components can be combined into reactive workflows, which can process
data entering the system from the outside world.

## Status

We are currently working on a new version of skitter, which aims to improve the
expressivity of the language while also making it easier to use Skitter on a
cluster.
This release is the last effect based version of Skitter.
The instructions in the "Getting started" section below only apply to this
release.

If you are interested in the most recent version of Skitter, please look at the
current status [on GitHub](https://github.com/mathsaey/skitter).

# Getting started

Information to get started with Skitter is provided below, some familiarity
with [elixir](https://elixir-lang.org/) and its tooling (`mix`, `iex`) is
assumed.

Documentation for this version of Skitter can be found
[here](https://soft.vub.ac.be/~mathsaey/skitter/docs/v0.1.1/).

## Installation

In order to use Skitter, you need to install
[elixir](https://elixir-lang.org/install.html).
Please ensure you use elixir version 1.8 or above.

Afterwards, clone the current version of the repository and fetch and build its
dependencies:

```
$ git clone --depth 1 --branch v0.1.1 https://github.com/mathsaey/skitter.git
$ cd skitter
$ mix deps.get
$ mix deps.compile
```

## Local use

You can use the elixir shell to play around with skitter in _local_ (i.e.
non-distributed) mode:

```
$ iex -S mix
```

In the shell, you can define components and workflows:

```
iex(1)> import Skitter.Component

iex(2)> component FahrenheitToCelcius, in: fahrenheit, out: celcius do
...(2)>   react fahrenheit do
...(2)>     ((fahrenheit - 32) * (5 / 9)) ~> celcius
...(2)>   end
...(2)> end

iex(3)> component Printer, in: data do
...(3)>   effect external_effect
...(3)>
...(3)>   react data do
...(3)>     IO.inspect(data)
...(3)>   end
...(3)> end

iex(4)> import Skitter.Workflow

iex(5)> workflow Example, in: fahrenheit do
...(5)>   converter = instance FahrenheitToCelcius
...(5)>   printer = instance Printer
...(5)>
...(5)>   fahrenheit ~> converter.fahrenheit
...(5)>   converter.celcius ~> printer.data
...(5)> end
```

Once defined, you can load the workflow and send it some data:

```
iex(6)> {:ok, instance} = Skitter.Runtime.load_workflow(Example)

iex(7)> Skitter.Runtime.react(instance, fahrenheit: 4)
```

Please look at the
[documentation](https://soft.vub.ac.be/~mathsaey/skitter/docs/v0.1.1/)
for more information.

## Distributed use

To run a distributed Skitter application, the component and workflow code should
be packaged in a `mix` project which is present on the worker and master nodes.
A small project with some example code to help you get started can be found 
[here](https://soft.vub.ac.be/~mathsaey/skitter/skitter_0.1.1_example.zip).

After unzipping the project, navigate to the project and fetch the dependencies:

```
$ cd skitter_0.1.1_example
$ mix deps.get
$ mix deps.compile
```

We can use `iex -S mix` to verify everything works in local mode:

```
$ iex -S mix

iex(1)> SkitterExample.load_and_react()
```

If everything works in local mode, we can try to execute Skitter in distributed
mode on our local machine. To do so, start two terminals and navigate to the
example project directory.

In one terminal, start a worker node:

```
$ mix skitter.worker
```

Start a master node in the other terminal. When starting a master node, pass
along the name of the worker node (`worker@<your-hostname-here>`) and a command
to evaluate (`Skitter.Example.load_and_react()` in our case):

```
$ mix skitter.master worker@hostname --eval "Skitter.Example.load_and_react()"
```

If everything is set up correctly, converted temperatures should be visible in
the worker terminal.

Once everything is set up, you can define your own components, workflows and
data delivery code based on the code in `lib/`.

To execute code on a cluster, ensure every node has a copy of the mix project
you are executing. Afterwards, run `mix skitter.worker` on every worker node.
Finally, start the master node with the names of the worker nodes (
`mix skitter.master worker@worker1-hostname worker@worker2=hostname … --eval "SkitterExample.load_and_react()"`
).
