![skitter logo](assets/logo_header.png)

A domain specific language for building horizontally scalable, reactive
workflow applications with custom distribution strategies.

Built in the context of my PhD at the
[Software Languages Lab](https://soft.vub.ac.be/).

# Skitter

Skitter is a reactive workflow system: it makes it possible to define data
processing pipelines which respond to incoming data automatically by combining
_components_ into a _workflow_.

A key difference between Skitter and other, related, technologies is the notion
of a _distribution strategy_: components in a Skitter application specify a
strategy which defines how the component is distributed over a cluster at
runtime.
This enables developers to implement custom distribution strategies based on
the component that is being distributed.
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

Coming soon.
