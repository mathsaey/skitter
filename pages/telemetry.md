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

All event names emitted by Skitter are prefixed with `:skitter`.

## Wrapped events

Certain events are wrapped in a call to `:telemetry.span/3`. These events are
marked as "wrapped events". When handling these events, a `start` and a `stop`
handler need to be defined.

For instance, to handle the `[:skitter, :worker, :process]` event, a handler
needs to be created for both `[:skitter, :worker, :process, :start]` and
`[:skitter, :worker, :process, :stop]`.

Additionally, an `exception` handler needs to be created if an exception might
occur in the wrapped event.

# Event Overview

- `:deploy` (wrapped): emitted when a workflow is deployed.
  - `:ref`: A reference which uniquely identifies this deployment. It is also
    returned by `Skitter.Runtime.deploy/1`.
  - `:workflow`: The `t:Skitter.Workflow.t/0` which is deployed. It is flattened
    (through the use of `Skitter.Workflow.flatten/1`) when passed along with
    the event.
  - `:nodes`: A list of `{name, index}` pairs. This list contains an
    entry for each node in the provided workflow. It can be used to match a
    workflow node to the indices returned by other events.
- `:send`: emitted when a message is sent using `Skitter.Worker.send/3`.
  - `:from`: The `t:pid/0` of the worker sending the message.
  - `:to`: The `t:pid/0` of the worker receiving the message.
  - `:message`: The message being sent.
  - `:invocation`: The invocation of the message being sent.

## Worker Events

All worker events are prefixed with `:worker`. The following events are emitted:

- `:init`: Sent when a worker is initialized.
  - `:pid`: The `t:pid/0` of the worker. Uniquely identifies the worker.
  - `:idx`: The index of the component in the workflow. This index uniquely
    identifies the component instance in the workflow. It is shared by all
    workers spawned for the component.
  - `:ref`: A reference which identifies the deployment of the worker. It is
    shared by all workers created for a single workflow. This reference is also
    returned by `Skitter.Runtime.deploy/1`.
  - `:tag`: The `t:Skitter.Worker.tag/0` of the worker.
- `:process` (wrapped): Sent when a worker processes a message.
  - `:pid`: The `t:pid/0` of the worker. Uniquely identifies the worker.
  - `:message`: The message to process.
  - `:invocation`: The invocation of the received message.
