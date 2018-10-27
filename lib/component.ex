# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Tools to interact with skitter components.

  A component is a collection of function implementations and metadata.
  Components can be _instantiated_ by embedding them inside a workflow.
  When this is done, the component instance is responsible for _reacting_ to
  any data it receives from the skitter runtime. The functions which are a
  part of the component definition define how the component instance responds
  to the incoming data. The metadata that makes up the other part of the
  component definition defines how a component can be embedded inside a
  workflow, how the skitter runtime should handle this component and provides
  documentation about the component. Various instances of the same component
  share the same metadata and function implementations, but cannot share any
  state.

  This module defines an interface that can be used to access the metadata and
  functionality offered by a component and its instances. Besides this, this
  modules defines the `component/3` macro which can be used to define a
  component.

  ## Functions

  This module defines two types of functions: functions which access the
  metadata of a component and functions which activate a function of a
  component. All metadata functions work on both components and instances,
  the other functions only work on the component or its instance. The following
  table provides a short overview of the functions in this module and the
  arguments they accept.

  | Function                 | Component / Instance |
  | ------------------------ | -------------------- |
  | `is_component?/1`        | _both_               |
  | `is_instance?/1`         | _both_               |
  | `name/1`                 | _both_               |
  | `description/1`          | _both_               |
  | `in_ports/1`             | _both_               |
  | `out_ports/1`            | _both_               |
  | `effects/1`              | _both_               |
  | `state_change?/1`        | _both_               |
  | `hidden_state_change?/1` | _both_               |
  | `external_effect?/1`     | _both_               |
  | `init/2`                 | component            |
  | `terminate/1`            | instance             |
  | `react/2`                | instance             |
  | `react_after_failure/2`  | instance             |
  | `create_checkpoint/1`    | instance             |
  | `clean_checkpoint/2`     | instance             |
  | `restore_checkpoint/2`   | component            |

  ## A note on doctests

  Since this module works on components and their instances, all code examples
  in the docs of this module assume the following components have been defined.
  More information about these definitions can be found in the
  `Skitter.Component.DSL` docs.

  ```
  component Identity, in: value, out: value do
    react value do
      value ~> value
    end
  end

  component Features, in: [foo, bar] do
    "Doesn' t do anything useful, but allows us to show all component aspects."

    effect state_change hidden
    effect external_effect

    fields f

    init {a, b} do
      f <~ a + b
    end

    react _foo, _bar do
    end

    create_checkpoint do
      f
    end

    restore_checkpoint v do
      f <~ v
    end
  end
  ```

  Besides this, an example instance is provided by a function:

  ```
  def example_instance() do
    {:ok, inst} = init(Identity, nil)
    inst
  end
  ```
  """

  alias Skitter.Component.Instance
  alias Skitter.Component.Metadata

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  Skitter component definition.

  A skitter component is represented by the elixir module which implements its
  functionality. This module should provide a `__skitter_metadata__/0` function.
  """
  @type t :: module()

  @typedoc """
  Component instance representation.

  A component instance contains a reference to its component along with some
  other data which is used by skitter's runtime. As this data can change between
  different versions of skitter, it is not documented here.
  """
  @opaque instance :: Skitter.Component.instance()

  @typedoc """
  Skitter port type.

  A port is simply defined by its name, which is represented as an atom.
  """
  @type port_name :: atom()

  @typedoc "Skitter effects"
  @type effect :: :external_effect | :state_change

  @typedoc "Possible properties of the `t:state_change` effect."
  @type state_change_properties :: [:hidden]
  @typedoc "Possible properties of the `t:external_effect` effect."
  @type external_effect_properties :: []

  @typedoc "Representation of component checkpoints"
  @type checkpoint :: any()

  @typedoc "type of the errors components can throw at runtime."
  @type runtime_error :: {:error, String.t()}

  # --------- #
  # Interface #
  # --------- #

  @doc """
  Verify if something is a component

  ## Examples

      iex> is_component?(5)
      false
      iex> is_component?(Enum)
      false
      iex> is_component?(Identity)
      true
  """
  @spec is_component?(any()) :: boolean()
  def is_component?(any)

  def is_component?(mod) when is_atom(mod) do
    function_exported?(mod, :__skitter_metadata__, 0) and
      match?(%Metadata{}, mod.__skitter_metadata__)
  end

  def is_component?(_), do: false

  @doc """
  Verify if something is a component instance

  ## Examples

      iex> is_instance?(:foo)
      false
      iex> is_instance?(example_instance())
      true
  """
  @spec is_instance?(any()) :: true | false
  def is_instance?(any)

  def is_instance?(%Instance{}), do: true
  def is_instance?(_), do: false

  @doc """
  Get the name of a component (instance)

  ## Examples

      iex> name(Identity)
      "Identity"
      iex> name(example_instance())
      "Identity"
  """
  @spec name(t() | instance()) :: String.t()
  def name(%Instance{component: comp}), do: name(comp)
  def name(comp), do: comp.__skitter_metadata__.name

  @doc """
  Get the description of a component (instance)

  An empty string is returned if no documentation is present.

  ## Examples

      iex> description(Identity)
      ""
      iex> description(example_instance())
      ""
      iex> description(Features)
      "Doesn't do anything useful, but allows us to show all component aspects."
  """
  @spec description(t() | instance()) :: String.t()
  def description(%Instance{component: comp}), do: description(comp)
  def description(comp), do: comp.__skitter_metadata__.description

  @doc """
  Get the in ports of a component (instance)

  The ports of a component are used to connect a component instance to other
  component instances in a given workflow. The skitter runtime use the in ports
  of a component to provide the data that the component instance will react to.

  In other words, data sent to an in port of a component instance will be
  provided as an argument to the `react` function of a component.

  ## Examples

      iex> in_ports(Identity)
      [:value]
      iex> in_ports(example_instance())
      [:value]
      iex> in_ports(Features)
      [:foo, :bar]
  """
  @spec in_ports(t() | instance()) :: [port_name(), ...]
  def in_ports(%Instance{component: comp}), do: in_ports(comp)
  def in_ports(comp), do: comp.__skitter_metadata__.in_ports

  @doc """
  Get the out ports of a component (instance)

  The ports of a component are used to connect a component instance to other
  component instances in a given workflow. A component instance can send data
  to its own out ports while it is reacting to data. In turn, the skitter
  runtime will send this data to any ports connected to this out port.

  ## Examples

      iex> out_ports(Identity)
      [:value]
      iex> out_ports(example_instance())
      [:value]
      iex> out_ports(Features)
      []
  """
  @spec out_ports(t() | instance()) :: [port_name()]
  def out_ports(%Instance{component: comp}), do: out_ports(comp)
  def out_ports(comp), do: comp.__skitter_metadata__.out_ports

  @doc """
  Get the arity of a component (instance)

  The arity of a component is equal to the amount of in ports the component has.
  See `in_ports/1` for more information.

  ## Examples

      iex> arity(Identity)
      1
      iex> arity(example_instance())
      1
      iex> arity(Features)
      2
  """
  @spec arity(t() | instance()) :: pos_integer()
  def arity(%Instance{component: comp}), do: arity(comp)
  def arity(comp), do: comp.__skitter_metadata__.arity

  @doc """
  Get the effects of a component (instance).

  The effects of a component describe the effects that an instance of this
  component may trigger when it is reacting to incoming data. These effects
  are used by the skitter runtime to determine how to handle distribution and
  fault tolerance.

  Calling this function directly is generally not required, instead, rely on
  more specific functions such as `state_change?/1`, `external_effect?/1`,
  etc.

  ## Examples

      iex> effects(Identity)
      []
      iex> effects(example_instance())
      []
      iex> effects(Features)
      [external_effect: [], state_change: [:hidden]]
  """
  @spec effects(t() | instance()) :: [
          {effect(), state_change_properties() | external_effect_properties()}
        ]
  def effects(%Instance{component: comp}), do: effects(comp)
  def effects(comp), do: comp.__skitter_metadata__.effects

  @doc """
  Verify if a component (instance) can update its state.

  A component can update its state if it has the `state_change` effect.
  This effect signifies that every call to react needs to access a shared
  state which may be modified.

  ## Examples

      iex> state_change?(Identity)
      false
      iex> state_change?(example_instance())
      false
      iex> state_change?(Features)
      true
  """
  @spec state_change?(t() | instance()) :: boolean()
  def state_change?(comp) do
    comp |> effects() |> Keyword.has_key?(:state_change)
  end

  @doc """
  Verify if a component (instance) can change its state without explicitly
  passing a new state.

  A component has a hidden state if it has the `state_change` effect with the
  `hidden` property. Components with a hidden state change manage their own
  state and do not hand it over to skitter every time `react` is called. To
  ensure that this hidden state is recoverable in the case of failure, these
  components are required to implement the `create_checkpoint` and
  `restore_checkpoint` callbacks.

  ## Examples

      iex> hidden_state_change?(Identity)
      false
      iex> hidden_state_change?(example_instance())
      false
      iex> hidden_state_change?(Features)
      true
  """
  @spec hidden_state_change?(t() | instance()) :: boolean()
  def hidden_state_change?(comp) do
    lst = comp |> effects() |> Keyword.get(:state_change, [])
    :hidden in lst
  end

  @doc """
  Verify if a component has external effects.

  A component has external effects if it provides the `external_effect` effect.
  A component with this effect specifies that the execution of
  `react` may lead to side effects (e.g I/O).

  When the execution of a component instance with this effect fails, the
  skitter runtime will re-execute `react` including its `after_failure` blocks.
  This makes it possible to clean up any external effects a previous, failed
  call to react (or react_after_failure) may have had.

  ## Examples

      iex> external_effect?(Identity)
      false
      iex> external_effect?(example_instance())
      false
      iex> external_effect?(Features)
      true
  """
  @spec external_effect?(t() | instance()) :: boolean()
  def external_effect?(comp) do
    comp |> effects() |> Keyword.has_key?(:external_effect)
  end

  @doc """
  Create a component instance.

  Instantiate a component based on the component definition and initialization
  arguments. The `args` value provided to this function will be passed to the
  `init` function of the component.

  ## Examples

      iex> init(Identity, nil)
      {:ok, %Instance{component: Identity, state: []}}
  """
  @spec init(t(), any()) :: {:ok, instance()} | runtime_error()
  def init(comp, args), do: comp.__skitter_init__(args)

  @doc """
  Ask a component instance to clean up its resources.

  This function will call the `terminate` function of the component instance.
  The terminate function of the component is used by the component instance to
  clean up any resources it may have opened.
  ## Examples

      iex> terminate(example_instance())
      :ok
      iex> terminate(Identity)
      ** (FunctionClauseError) no function clause matching in Skitter.Component.terminate/1
  """
  @spec terminate(instance()) :: :ok | runtime_error()
  def terminate(inst = %Instance{component: comp}) do
    comp.__skitter_terminate__(inst)
  end

  @doc """
  Make the component instance react to data.

  This function will cause the react function of the component to be activated.
  The arguments that should be passed to this react function should be wrapped
  inside a list which will be automatically deconstructed by the react function.

  ## Examples

      iex> react(example_instance(), [20])
      {:ok, %Instance{component: Identity, state: []}, [value: 20]}
  """
  @spec react(instance(), [any(), ...]) ::
          {:ok, instance(), [{port_name(), any()}]}
          | runtime_error()
  def react(inst = %Instance{component: comp}, args) do
    comp.__skitter_react__(inst, args)
  end

  @doc """
  Make the component instance react to incoming data after a previous attempt to
  do so failed.

  This function performs the same job as `react/2`. However, it will trigger any
  code defined in an after failure block inside the component instance.

  ## Examples

      iex> react_after_failure(example_instance(), [20])
      {:ok, %Instance{component: Identity, state: []}, [value: 20]}
  """
  @spec react_after_failure(instance(), [any(), ...]) ::
          {:ok, instance(), [{port_name(), any()}]}
          | runtime_error()
  def react_after_failure(inst = %Instance{component: comp}, args) do
    comp.__skitter_react_after_failure__(inst, args)
  end

  @doc """
  Ask a component instance to create a checkpoint.

  This will call the checkpoint function of the component instance. This
  function should return a valid checkpoint which can be used to restore the
  component instance if the component fails later.

  ## Examples

      iex> {:ok, inst} = init(Features, {3, 4})
      {:ok, %Instance{component: Features, state: [f: 7]}}
      iex> create_checkpoint(inst)
      {:ok, 7}
  """
  @spec create_checkpoint(instance()) :: {:ok, checkpoint()} | runtime_error()
  def create_checkpoint(inst = %Instance{component: comp}) do
    comp.__skitter_create_checkpoint__(inst)
  end

  @doc """
  Restore a component instance based on a checkpoint.

  This function will create a new component instance and use the
  `restore_checkpoint` function of that component to restore the state of that
  instance based on a checkpoint.

  ## Examples

      iex> restore_checkpoint(Features, 7)
      {:ok, %Skitter.Component.Instance{component: Features, state: [f: 7]}}
  """
  @spec restore_checkpoint(t(), checkpoint()) ::
          {:ok, instance()} | runtime_error()
  def restore_checkpoint(comp, checkpoint),
    do: comp.__skitter_restore_checkpoint__(checkpoint)

  @doc """
    Remove an old checkpoint of a component instance.

    This function calls the `clean_checkpoint` function of a component instance.
    This function is responsible for removing any resources associated with a
    checkpoint which will not be used anymore.

  ## Examples

      iex> {:ok, inst} = restore_checkpoint(Features, 10)
      iex> clean_checkpoint(inst, 10)
      :ok
      iex> clean_checkpoint(Features, 10)
      ** (FunctionClauseError) no function clause matching in Skitter.Component.clean_checkpoint/2
  """
  @spec clean_checkpoint(instance(), checkpoint()) :: :ok | runtime_error()
  def clean_checkpoint(inst = %Instance{component: comp}, checkpoint) do
    comp.__skitter_clean_checkpoint__(inst, checkpoint)
  end

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Create a component.

  This macro is a shorthand for accessing the
  `Skitter.Component.DSL.component/3` macro, which enables the creation of
  skitter components.
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
