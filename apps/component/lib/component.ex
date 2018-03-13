defmodule Skitter.Component do
  @moduledoc """
  A behaviour module to implement and verify Skitter components.
  """

  # --------- #
  # Interface #
  # --------- #

  @doc """
  Return the name of the component.

  _This function is automatically generated when using `defcomponent/3`._

  The name of a component is determined as follows:
  - If an `@name` attribute is present in the component definition, this
    attribute will define the name.
  - Otherwise, a name is generated from the name of the macro.
    This name is generated from the final part of the component name.
    Uppercase letters in the module name will be prepended by a space.
    Acronyms are preserved during this transformation.

  ## Examples

  ```
  defcomponent ACKFooBar, [] do
    @name Baz
    ...
  end
  ```

  Will have the name "Baz".

  ```
  defcomponent ACKFooBar, [] do
    ...
  end
  ```

  Will have the name "ACK Foo Bar".
  """
  @callback name() :: String.t

  @doc """
  Return a detailed description of the component and its behaviour.

  _This function is automatically generated when using `defcomponent/3`._

  The description this function returns is obtained from:
  - The string added to the `@desc` module attribute.
  - The documentation added to the `@moduledoc` attribute, if no `@desc`
    attribute is present.
  - An empty string, if neither is present. Skitter will provide a warning when
    this is the case.
  """
  @callback desc() :: String.t

  @doc """
  Return a list of the effects of a component.

  _This function is automatically generated when using `defcomponent/3`._

  Please look at the `Skitter.Component` documentation for more information
  about effects.
  """
  @callback effects() :: [:internal_state | :external_effects]

  @doc """
  Return a list of the in_ports of a component.

  _This function is automatically generated when using `defcomponent/3`._

  Please look at the `Skitter.Component` documentation for more information
  about ports.
  """
  @callback in_ports() :: [atom(), ...]

  @doc """
  Return a list of the out_ports of a component.

  _This function is automatically generated when using `defcomponent/3`._

  Please look at the `Skitter.Component` documentation for more information
  about ports.
  """
  @callback out_ports() :: [atom()]

  defmodule DefinitionError do
    @moduledoc """
    This error is raised when a component definition is invalid.
    """
    defexception [:message]

    def exception(val) do
      %DefinitionError{message: val}
    end
  end

  # -------------------- #
  # Component Generation #
  # -------------------- #

  defmodule Transform do
    @moduledoc false

    @doc """
    Transform the effects of a component.

    :no_effects is transformed into an empty list
    atoms are wrapped inside a list
    everything else is left alone.
    """
    def effects(:no_effects), do: []
    def effects(some_atom) when is_atom(some_atom), do: [some_atom]
    def effects(something_else), do: something_else

    @doc """
    Transform the name of a component.

    This is done by modifying the `@name` module attribute.

    If @name is specified, we leave it alone
    Otherwise, we generate a name as specified in the `Skitter.Component.name/0`
    callback.
    """
    def name(env) do
      regex = ~r/([[:upper:]]+(?=[[:upper:]])|[[:upper:]][[:lower:]]*)/
      module = env.module
      name = case Module.get_attribute(module, :name) do
        nil ->
          name = module |> Atom.to_string |> String.split(".") |> Enum.at(-1)
          Regex.replace(regex, name, " \\0") |> String.trim
        name ->
          name
      end
      Module.put_attribute(module, :name, name)
    end

    @doc """
    Transform the description of a component.

    This is done by modifying the `@desc` module attribute.

    If @desc is specified we leave it alone.
    Otherwise, if @moduledoc is specified, use it as a description.
    """
    def desc(env) do
      module = env.module
      desc = Module.get_attribute(module, :desc)
      docs = Module.get_attribute(module, :moduledoc)

      res = case {desc, docs} do
        {desc, _} when not is_nil(desc) ->
          desc
        {nil, docs} when not is_nil(docs) ->
          docs
        _ ->
          nil
      end
      Module.put_attribute(module, :desc, res)
    end
  end

  defmodule Verify do
    @moduledoc false

    @allowed_effects [:internal_state, :external_effects]

    @doc """
    Ensure effects are valid.

    Empty lists are valid.
    Lists with allowed effects are valid
    Everything else is invlaid.
    """
    def effects!([]), do: []

    def effects!(lst) when is_list(lst) do
      case Enum.reject(lst, fn(e) -> e in @allowed_effects end) do
        [] ->
          lst
        errLst ->
          raise DefinitionError, "Invalid effects #{Enum.join(errLst, ", ")}"
      end
    end

    def effects!(other) do
      raise DefinitionError, "Invalid effect #{inspect(other)}"
    end

    @doc """
    Check if description is present.

    Warn if this is not the case.
    """
    defmacro documentation(env) do
      if Module.get_attribute(env.module, :desc) == nil do
        IO.warn "Missing component documentation"
      end
    end

    @doc """
    Verify that required attributes are present.
    """
    defmacro required_attributes!(env) do
      if Module.get_attribute(env.module, :in_ports) == nil do
        raise DefinitionError, "Missing `@in_ports` attribute"
      end
      if Module.get_attribute(env.module, :out_ports) == nil do
        raise DefinitionError, "Missing `@out_ports` attribute"
      end
    end
  end

  defmodule Generate do
    @moduledoc false
    defmacro name(env) do
      quote do
        def name, do: unquote(Module.get_attribute(env.module, :name))
      end
    end
    defmacro desc(env) do
      quote do
        def desc, do: unquote(Module.get_attribute(env.module, :desc))
      end
    end
    defmacro in_ports(env) do
      quote do
        def in_ports, do: unquote(Module.get_attribute(env.module, :in_ports))
      end
    end
    defmacro out_ports(env) do
      quote do
        def out_ports, do: unquote(Module.get_attribute(env.module, :out_ports))
      end
    end
  end

  @doc """
  Define a Skitter component.
  """
  defmacro defcomponent(name, effects, _opts \\ [], do: body) do
    effects = effects |> Transform.effects |> Verify.effects!

    quote do
      defmodule unquote(name) do
        @behaviour Skitter.Component

        # The following callbacks:
        #   - Transform some attributes
        #   - Verify the necessary attributes are present and correct
        #   - Generate functions
        # Since callbacks which are registered first run last, the following
        # callbacks are executed in the opposite order in which they are listed.

        # Verify module attributes
        @before_compile {Verify, :required_attributes!}
        @before_compile {Verify, :documentation}
        # Generate callbacks
        @before_compile {Generate, :name}
        @before_compile {Generate, :desc}
        @before_compile {Generate, :in_ports}
        @before_compile {Generate, :out_ports}
        # Transform attributes
        @before_compile {Transform, :name}
        @before_compile {Transform, :desc}

        # Insert effects function
        def effects, do: unquote(effects)

        # Insert the provided body
        unquote(body)
      end
    end
  end
end
