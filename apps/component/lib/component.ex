defmodule Skitter.Component do
  @moduledoc """
  Behaviour module and interface for skitter components.

  A component is the foundation of a skitter workflow. A skitter component can
  be plugged into a workflow, after which is it responsible for processing
  any data it receives.

  This module defines two main facilities to work with skitter components:
  - An interface which can be used to work with existing components
  - A behaviour which any skitter component must implement.

  Developers who want to create their own components should look into the
  `Skitter.Component.DSL` module, which provides abstractions that greatly
  facilitate the implementation of skitter components.
  """

  # --------- #
  # Interface #
  # --------- #

  @doc "Get the name of a component."
  def name(comp), do: comp.__skitter_metadata__.name

  @doc """
  Get the description of a component.

  An empty string is returned if no documentation is present.
  """
  def description(comp), do: comp.__skitter_metadata__.description

  @doc """
  Get the in ports of a component.

  The ports of a component are used to connect a component to other components
  in a given workflow. The skitter runtime can use the in ports of a component
  to provide the data that the component will react to.
  In other words, data sent to an in port of a component will be provided as
  an argument to the `c:__skitter_react__/2` callback of a component.
  """
  def in_ports(comp), do: comp.__skitter_metadata__.in_ports

  @doc """
  Get the out ports of a component.

  The ports of a component are used to connect a component to other components
  in a given workflow. A component can send data to its own out ports while it
  reacts to data. In turn, the skitter runtime will send this data to any ports
  which are connected to this out port.
  """
  def out_ports(comp), do: comp.__skitter_metadata__.out_ports

  @doc """
  Get the effects of a component.

  The effects of a component describe the effects that a component may trigger
  when it reacts to incoming data. These effects are used by the skitter
  runtime to determine how to handle distribution and fault tolerance.

  Calling this function directly is generally not required, instead, rely on
  more specific functions such as `state_change?/1`, `external_effect?/1`,
  etc.
  """
  def effects(comp), do: comp.__skitter_metadata__.effects

  @doc """
  Verify if a component can update its state.

  A component can update its state if it has the `state_change` effect.
  This effect signifies that every call to `c:__skitter_react__/2` needs to
  access a shared state which may be modified.
  """
  def state_change?(comp) do
    comp |> effects() |> Keyword.has_key?(:state_change)
  end

  @doc """
  Verify if a component can change its state without explicitly passing a new
  state.

  A component has a hidden state if it has the `state_change` effect with the
  `hidden` property. Components with a hidden state change manage their own
  state and do not hand it over to skitter every time `c:__skitter_react__/2`
  is called. Instead, these components return a _reference_ to their internal
  state. Furthermore, these components are required to implement the
  `c:__skitter_checkpoint__/1` and `c:__skitter_restore__/1` callbacks.
  """
  def hidden_state_change?(comp) do
    lst = comp |> effects() |> Keyword.get(:state_change, [])
    :hidden in lst
  end

  @doc """
  Verify if a component has external effects.

  A component has external effects if it provides the `external_effect` effect.
  A component with this effect specifies that the execution of
  `c:__skitter_react__/2` may lead to side effects beyond the scope of the
  component (e.g. I/O).

  When the execution of a component with this effect fails, the skitter runtime
  will re-execute it by calling `c:__skitter_react_after_failure__/2`. This
  makes it possible to clean up any external effects a previous, failed, call
  may have had.
  """
  def external_effect?(comp) do
    comp |> effects() |> Keyword.has_key?(:external_effect)
  end

  @doc "Call the `c:__skitter_init__/1` callback of a component."
  def init(comp, args), do: comp.__skitter_init__(args)

  @doc "Call the `c:__skitter_terminate__/1` callback of a component."
  def terminate(comp, inst), do: comp.__skitter_terminate__(inst)

  @doc "Call the `c:__skitter_checkpoint__/1` callback of a component."
  def checkpoint(comp, inst), do: comp.__skitter_checkpoint__(inst)

  @doc "Call the `c:__skitter_restore__/1` callback of a component."
  def restore(comp, checkpoint), do: comp.__skitter_restore__(checkpoint)

  @doc "Call the `c:__skitter_react__/2` callback of a component."
  def react(comp, inst, args), do: comp.__skitter_react__(inst, args)

  @doc "Call the `c:__skitter_react_after_failure__/2` callback of a component."
  def react_after_failure(comp, inst, args) do
    comp.__skitter_react_after_failure__(inst, args)
  end

  # ------------------- #
  # Component Callbacks #
  # ------------------- #

  @typedoc "Internal representation of a component."
  @type component :: module()

  @typedoc """
  Skitter checkpoint representation.

  Components are free to choose the exact representation of a checkpoint.
  Therefore, a checkpoint is represented by the `any()` type.
  """
  @type checkpoint :: any()

  @typedoc """
  Component instance representation

  Components are free to choose the exact representation of an instance.
  Therefore, an instance is represented by the `any()` type.
  """
  @type instance :: String.t()

  @typedoc """
  Type of the "reason" added to an error.

  The reason of an error should be represented as a string.
  """
  @type reason :: any()

  @doc """
  Provide the metadata of the component.

  The required fields are specified in the documentation of the
  `t:Skitter.Component.Metadata.t/0` type.
  """
  @callback __skitter_metadata__ :: Skitter.Component.Metadata.t()

  @doc """
  Initialize an instance of the component.

  This callback should return `{:ok, instance}`, where the instance can be used
  by `c:__skitter_react__/2` to react to incoming data. If something goes
  wrong, `{:error, reason}` can be returned instead. `reason` should be a
  string, which will be returned to the user.

  This callback accepts a single argument. This argument contains user-provided
  data which will contain the necessary parameters to initialize the component.
  """
  @callback __skitter_init__([]) :: {:ok, instance} | {:error, reason}

  @doc """
  Clean up resources associated with the instance of a component.

  This callback is called by the skitter runtime before it shuts down a
  component instance, which is passed to this callback as an argument.
  This callback should clean up any resources associated with the component
  instance.

  If the callback is successful, it should return `:ok`, otherwise, return an
  `{:error, reason}` tuple.
  """
  @callback __skitter_terminate__(instance) :: :ok | {:error, reason}

  @doc """
  Return a reference to a checkpoint of the internal state.

  This callback is designed for components which manage their own internal
  state. Other components should simply return `:nocheckpoint`.

  Skitter automatically checkpoints the internal state which it receives from
  the invocation of react. However, if a component manages its own state (as
  specified by the `hidden` property of the `:state_change` effect), skitter
  cannot access this data. Therefore, skitter can use this callback to
  explicitly request a checkpoint to be made. In turn, this callback should
  return a checkpoint which it can use to reconstruct the current internal
  state later on.

  This callback receives a component instance as an argument, and should return
  `{:ok, checkpoint}` when successful.
  """
  @callback __skitter_checkpoint__(instance) ::
              {:ok, checkpoint} | :nocheckpoint

  @doc """
  Reconstruct a component instance based on a checkpoint.

  This callback is the counterpart of `__skitter_checkpoint__/1`, it takes a
  checkpoint and recreates a component instance based on this checkpoint.
  """
  @callback __skitter_restore__(checkpoint) :: {:ok, instance} | :nocheckpoint

  @doc """
  React to incoming data.

  This callback is the bread and butter of a skitter component. It accepts
  a component instance and a list of arguments. The instance is provided by
  `__skitter_init__/1`, and the components are retrieved from the `in_ports`
  of the component.

  Use this callback to process any incoming data. When the processing is
  successful, the component should return `{:ok, instance, kwlist}`.
  `instance` represents the current instance of the component; if the component
  has the `state_change` effect, this instance may be different from the
  `instance` argument. The `kwlist` should be a keyword list which specifies
  the value should be sent to the which output port.

  If the execution fails, `{:error, reason}` can be returned.
  """
  @callback __skitter_react__(instance, []) ::
              {:ok, instance, [keyword()]} | {:error, reason}

  @doc """
  React to incoming data after a failure.

  The inner working of this callback is identical to `c:__skitter_react__/2`,
  however, this callback is only called by the skitter runtime if a previous
  call to `c:__skitter_react__/2` failed. Therefore, this callback can be used
  to clean up any external effect which may have occurred during the call to
  `c:__skitter_react__/2`.

  This callback should be identical to `c:__skitter_react__/2` if the component
  has no external effects.
  """
  @callback __skitter_react_after_failure__(instance, []) ::
              {:ok, instance, [keyword()]} | {:error, reason}

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Shorthand for `Skitter.Component.DSL.component/3`

  This macro simply requires the `Skitter.Component.DSL` module, and calls
  `Skitter.Component.DSL.component/3` with the provided arguments.
  Refer to the documentation of `Skitter.Component.DSL.component/3` for
  additional information.
  """
  defmacro component(name, ports, do: body) do
    quote do
      require Skitter.Component.DSL

      Skitter.Component.DSL.component unquote(name), unquote(ports) do
        unquote(body)
      end
    end
  end
end
