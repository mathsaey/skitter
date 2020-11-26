![skitter logo](https://raw.githubusercontent.com/mathsaey/skitter/develop/assets/logo.png)

A domain specific language for building horizontally scalable, reactive
workflow applications.
Built in the context of my PhD at the
[Software Languages Lab](https://soft.vub.ac.be/).

# Skitter

Skitter is a component agnostic, reactive workflow system; it makes it possible
to wrap arbitrary data processing applications into _reactive components_.
These components can be combined into reactive workflows, which can be deployed
over a cluster.
Once deployed, a reactive workflow can process data entering the system from
the outside world.

In order to support the distribution of arbitrary components over a cluster,
Skitter components define a _strategy_: a meta-level language construct which
defines how components are distributed over a cluster.
Through the use of these strategies, a programmer writing a Skitter application
can select the most appropriate distribution strategy based on the exact
properties of the reactive component.

## Status

__This version of skitter is a work in progress. It is currently not usable.__
Information on using the earlier, effect based, version on Skitter can be found
[here](https://soft.vub.ac.be/~mathsaey/skitter/docs/v0.1.1/).

# Getting started

## Installation

Skitter is distributed as a set of Erlang/Elixir releases bundled with a script
to start these releases on a cluster. To install Skitter, you can either build
it from source, or download a precompiled distribution.

Please note that we only provide precompiled versions for linux. Furthermore,
the deploy script only works on unix machines.

### Building the Skitter distribution

To build Skitter, you need to have a recent version of
[elixir](https://elixir-lang.org/).
Currently, Skitter requires elixir version 1.11 or above.

Once Elixir is installed, you can download the latest version of Skitter and use
`mix` to build a release:

```
$ git clone https://github.com/mathsaey/skitter.git
$ cd skitter
$ mix deps.get
$ mix release
```

This command builds a release of the various Skitter applications and packages
them with the deployment script.
All of these artefacts will be placed in `_build/prod/rel/`.
Alternatively, `--path <path>` can be passed to `mix build` to directly save the
artefacts to another location.

Since Elixir releases are self-contained there is no need to have Elixir or its
dependencies on your system after the release has been built.

### Download a distribution

Builds of Skitter can be found [here](https://soft.vub.ac.be/~mathsaey/skitter/build/).
Builds are marked as `skitter.<version>.<arch>-<vendor-os>-<abi>.tar.gz`.
Once you have selected the appropriate release, you can download and extract it:

```
$ wget https://soft.vub.ac.be/~mathsaey/skitter/build/skitter.latest.x86_64-unknown-linux-gnu.tar.gz
$ tar xf skitter.latest.x86_64-unknown-linux-gnu.tar.gz
```

Note that dependency issues may cause the prepackaged release to not work on
your system. In this case, please build the Skitter distribution manually.

## Use

Once you have built or downloaded the Skitter distribution, you can navigate to
its directory and use the `skitter` script to start and manage skitter.
Run `./skitter help` to get started.
