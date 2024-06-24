# Operations

Skitter operations represent a reusable data processing step. An operation is
responsible for processing any data it receives, potentially emitting new data
in the process. Operations receive inputs on their _input ports_ and emit
output on their _output ports_. An operation is always combined with a
distribution strategy, which determines how the operation is distributed.

Operations are defined through the use of
`Skitter.DSL.Operation.defoperation/3`. As a first example, consider the
following operation, which adds 1 to each data record it receives.

```
defoperation Increment, in: value, out: incremented, strategy: Skitter.BIS.ImmutableLocal do
  defcb react(value) do
    value + 1 ~> incremented
  end
end
```

This definition consists of meta-information about the operation and a
_callback definition_. The meta-information specifies that the operation can
accept values from a single input stream: `value`, that it produces a single
output stream: `incremented`, and that its default strategy is
`Skitter.BIS.ImmutableLocal`.

The `Increment` operation defines a single callback, `react`, which is called
when a new value arrives on the `value` stream. The callback is called with the
received value, adds 1 to it and _emits_ the result to the `incremented` output
stream through the use of the [`~>`](`Skitter.DSL.Operation.~>/2`) operator.

## (Default) strategies

At runtime, an operation is always paired with a distribution strategy, which
determines how it behaves. This pairing can happen in two places:

* An operation can specify a default distribution strategy which is used when
  the operation is not paired with another distribution strategy in a workflow.
* When an operation is embedded in a workflow as a
  [node](`Skitter.DSL.Workflow.node/2`), a strategy can be specified through
  the use of `with:`. This strategy always takes precedence over a default
  distribution strategy.

A distribution strategy specifies which callbacks an operation should
implement. For instance, `Skitter.BIS.ImmutableLocal` specifies that an
operation must define a `react` callback and that this callback will be called
for every incoming data element. It is therefore recommended to always specify
a default distribution strategy when defining an operation.

### Selecting a strategy

The appropriate strategy to use for an operation is determined by the
properties of the operation. For instance, if an operation is entirely
stateless, `Skitter.BIS.ImmutableLocal` is an appropriate choice. If an
operation needs to manage some state which is partitioned over several keys,
`Skitter.BIS.KeyedState` may be the right choice. If none of the built-in
strategies of Skitter are appropriate for the operation you are writing, it is
possible to define your own, as we discuss in the next section.

### Steps to write an operation

To define an operation, follow these steps:

1. Figure out the properties of the operation.
2. Based on these properties, select an appropriate distribution strategy.
3. Read the documentation of the distribution strategy and determine which
   callbacks your operation needs to implement.
   - If you need to write your own distribution strategy, determine the
     interface between the strategy and operation.
4. Write the operation definition by defining the appropriate callbacks in
   `Skitter.DSL.Operation.defoperation/3`.

## Dealing with state

Often, operations needs to manage some form of state. As an example, let's write
a `Count` operation which counts the amount of times it sees each value:

```
defoperation Count, in: value, out: seen, strategy: Skitter.BIS.KeyedState do
  initial_state 0

  defcb key(value), do: value

  defcb react(value) do
    state() <~ state() + 1
    {value, state()} ~> seen
  end
end
```

The definition of this operation is similar to the definition of `Increment`.
However, since this operation needs to manage state, we use the
`Skitter.BIS.KeyedState` strategy. This strategy separates the incoming data
elements based on some key, and maintains a state for each key. When a new data
element arrives, the `react` callback is called with the received value and
with the state of that key as its state. Inside react, this state can be
accessed through the use of [`state()`](`Skitter.DSL.Operation.state/0`) and
updated through the use of [`state() <~`](`Skitter.DSL.Operation.<~/2`).

The operation also defines its initial state by defining a callback named
`initial_state`, which accepts no arguments. As a syntactic convenience,
[`initial_state`](`Skitter.DSL.Operation.initial_state/1`) can be used to
define its initial state.

Finally, the `Skitter.BIS.KeyedState` strategy requires that operations define
a `key` callback which obtains a key for an incoming data record. In the case
of `Count`, the incoming data record is used as key.

### Complex state

Sometimes, operations maintain a complex state, defined as a struct with
several fields. The operation DSL defines
[`state_struct/1`](`Skitter.DSL.Operation.state_struct/1`),
[`<~`](`Skitter.DSL.Operation.<~/2`) and
[`~f()`](`Skitter.DSL.Operation.sigil_f/2`) to facilitate this:

```
defoperation Average, in: value, out: average, strategy: Skitter.BIS.KeyedState do
  state_struct total: 0, count: 0

  defcb react(val) do
    count <~ ~f{count} + 1
    total <~ ~f{total} + val
    ~f{total} / ~f{count} ~> average
  end
end
```

See `Skitter.DSL.Operation.state_struct/1` for more information.

## Other features

### Emitting values

The [`~>`](`Skitter.DSL.Operation.~>/2`) operator is used to publish data to an
out port inside a callback. The [`~>>`](`Skitter.DSL.Operation.~>>/2`) operator
can be used to emit several values at once. For instance, `[1, 2, 3] ~>> port`
will emit, `1`, `2` and `3` to port, one after the other.
As a special case, a (potentially infinite) Elixir stream can be passed to this
operator. Every value in this stream will then be emitted to the output stream.
If the stream is infinite, the operation will not respond to new data elements,
as it is busy emitting the values in the stream.

### Source operations

Sources are defined as operations in Skitter. To define a source, select a
distribution strategy which defines a source (such as
`Skitter.BIS.StreamSource`) and implement the callbacks defined in its
interface.

### Configuration data

Often, an operation is created with an immutable state, which remains
unmodified throughout the lifetime of the operation. In Skitter, this immutable
state may be stored in the so-called _configuration_ data, which can be accessed
inside a callback through the use of
[`config()`](`Skitter.DSL.Operation.config/0`). Typically, strategies enable
operations to implement a `conf` callback which defines the initial value of
this configuration data.

As an example, the `Skitter.BIO.Map` operation stores the function to execute
inside its configuration data:

```
defoperation Skitter.BIO.Map, in: _, out: _ strategy: Skitter.BIS.ImmutableLocal do
  defcb conf(func), do: func
  defcb react(arg), do: config().(arg) ~> _
end
```

### Accessing token information

A value received on an operation's input stream is wrapped inside a so-called
_token_, which contains additional information about the received data, such
as the port it was received on. If the strategy does not modify this token,
this information can be accessed inside a callback. For instance,
[`port_of/1`](`Skitter.DSL.Operation.port_of/1`) can be used to obtain the port
a data record was received on.

Operations can also add information to such a token through the use of
[`extend_meta/3`](`Skitter.DSL.Operation.extend_meta/3`),
[`inherit_meta/2`](`Skitter.DSL.Operation.inherit_meta/2`), or the functions
defined in `Skitter.Token`. Afterwards, this data can be obtained through the
use of [`meta_of/1`](`Skitter.DSL.Operation.meta_of/1`).
