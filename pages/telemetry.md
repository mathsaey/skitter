# Telemetry

This page details the telemetry events emitted by Skitter.

_This page is only relevant for those who wish to intercept the telemetry events
produced by Skitter. It is not relevant if you wish to write and deploy a
Skitter application._

Skitter emits various telemetry events which can be used to introspect the
current state of the runtime system. This page details the various events
produced by the Skitter runtime system, along with the meta-information passed
with these events. Note that these events are only produced when `telemetry` is
set to `true` in the Skitter application environment.

## Writing telemetry handlers

Telemetry events emitted by Skitter include a lot of information which may be
quite large. For instance, many events include a `t:Skitter.Strategy.context/0`
struct, which contains a reference to the deployment data, which may be quite
large. Developers who write event handlers which forward events to other
processes should keep this in mind and only forward the meta information they
require. This is especially relevant when data may be sent across the network.

## Telemetry Events

### Wrapped Events

The events described in this section are wrapped in a call to
`:telemetry.span/3`. This means that a `:start`, `:stop`, and `:exception`
handler may be defined for each of these events. For instance, to handle the
`[:skitter, :foo]` event, handlers for `[:skitter, :foo, :start]`,
`[:skitter, :foo, :stop]` and `[:skitter, :foo, :exception]` may need to be
defined. Please refer to the `:telemetry.span/3` documentation for more
information.

The listed fields are added to both `:start` and `:stop` events. Furthermore,
a `:result` field is added to the meta-information of every `:stop` event,
which contains the result of the wrapped code.

#### Hooks

* `[:skitter, :hook, :deploy]`: Emitted when the
  `c:Skitter.Strategy.Component.deploy/1` hook of a strategy is called.
  * `:context`: The context passed to `c:Skitter.Strategy.Component.deploy/1`
  * `:result` (only for the `:stop` event): the return value of the hook. This
    data will be stored inside the strategy's deployment.
* `[:skitter, :hook, deliver]`: Emitted when the `deliver` hook of a strategy is
  * `:context`, `:data`, `:port`: the arguments passed to
    `c:Skitter.Strategy.Component.deliver/3`.
  * `:pid`: The `t:pid/0` of the process calling the hook. Note that this hook
    is called from within a worker of the strategy emitting the data, so this
    pid will not refer to a worker of the component which should receive the
    data. Instead, it will refer to a worker of its predecessor.
  * `:result` (only for the `:stop` event). The result of the
    `c:Skitter.Strategy.Component.deliver/3` hook is not used by the runtime
    system, so you should not use this.
* `[:skitter, :hook, process]`: Emitted when the
  `c:Skitter.Strategy.Component.process/4` hook of a strategy is called.
  * `:context`, `:message`, `:state`, `:tag`: the arguments passed to
    `c:Skitter.Strategy.Component.process/4`.
  * `:pid`: The `t:pid/0` of the worker calling the hook.
  * `:result` (only for the `:stop` event): the return value of the hook. This
    data will be used as the new state of the worker which called the hook.

#### Component Callbacks

* `[:skitter, :component, :call]`: Emitted when a component callback is called.
  * `:pid`: The `t:pid/0` of the worker calling the callback.
  * `:component`, `:name`, `:state`, `:config`, `:args`: The arguments passed
    `Skitter.Component.call/5`.

### Unwrapped Events

The events described in this section are not wrapped and are emitted by
`:telemetry.execute/3`.

#### Runtime

* `[:skitter, :worker, :init]`: Emitted when a new worker is initialized. Note
  that, when a workflow is deployed, the workers are only initialized after the
  `deploy` hook of each component is called.
  * `context`: The context the worker was deployed with.
  * `state`: The initial state of the worker.
  * `tag`: The worker `t:Skitter.Worker.tag/0`
  * `pid`: The `t:pid/0` of the worker. Uniquely identifies the worker.
* `[:skitter, :worker, :send]`: Emitted when a message is sent using
  `Skitter.Worker.send/3`.
  * `:from`: The `t:pid/0` of the worker sending the message.
  * `:to`: The `t:pid/0` of the worker receiving the message.
  * `:message`: The message being sent.
  * `:invocation`: The `t:Skitter.Invocation.t/0` of the message being sent.
* `[:skitter, :runtime, emit]`: Emitted when a strategy emits data using
  `Skitter.Strategy.Component.emit/3`.
  * `context`: The context of the hook emitting the data.
  * `emit`: The emitted data: `t:Skitter.Component.emit/0`.
  * `invocation`: The invocation to use. May be a function which returns an
  invocation when called.
* `[:skitter, :runtime, :deploy]`: Emitted when a workflow is deployed. The
  event is emitted after everything is ready, but before
  `Skitter.Runtime.deploy/1` returns.

#### Remote

* `[:skitter, :remote, :up, :worker]`: Emitted when a worker runtime is
  connected to a master runtime. This event can only occur on a skitter runtime
  in `:master` mode.
  * `remote`: The name of the remote runtime we connected to.
  * `:tags`: The list of worker `t:Skitter.Remote.tag/0`
* `[:skitter, :remote, :down, :worker]`: Emitted when we disconnect from a
  worker. This event can only occur on a skitter runtime in `:master` mode.
  * `remote`: The name of the remote runtime we disconnected from.
  * `reason`: `:down` or `:remove`. In the first case, the remote runtime went
    down, in the second case, the remote runtime was briefly connected to the
    local runtime, after which it rejected the connection.
