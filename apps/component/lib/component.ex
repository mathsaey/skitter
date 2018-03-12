defmodule Skitter.Component do
  @moduledoc """
  A behaviour module to implement and verify Skitter components.
  """

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

  Returns a list with all of the components effects.
  Please look at the `Skitter.Component` documentation for more information
  about effects.
  """
  @callback effects() :: [:internal_state | :external_effects]

  defmodule DefinitionError do
    @moduledoc """
    This error is raised when a component definition is invalid.
    """
    defexception [:message]

    def exception(val) do
      %DefinitionError{message: val}
    end
  end

  defmodule Verification do
    @moduledoc false

    @allowed_effects [:internal_state, :external_effects]

    @doc """
    Ensure all the required attributes (effects, in_ports, out_ports)
    are present.

    Raise an error if something is missing.
    """
    defmacro required_attributes(env) do
      mod = env.module

      if Module.get_attribute(mod, :effects) == nil do
        raise DefinitionError, "Missing `@effects` attribute"
      end
      if Module.get_attribute(mod, :in_ports) == nil do
        raise DefinitionError, "Missing `@in_ports` attribute"
      end
      if Module.get_attribute(mod, :out_ports) == nil do
        raise DefinitionError, "Missing `@out_ports` attribute"
      end
    end

    @doc """
    Ensure the provided effects are valid.
    """
    defmacro effects_correct(env) do
      mod = env.module
      eff = Module.get_attribute(mod, :effects)

      lst = case eff do
        l when is_list(l) -> Enum.reject(l, fn(e) -> e in @allowed_effects end)
        :noeffects -> []
        [] -> []
        _ -> raise DefinitionError, "Invalid effects #{eff}"
      end

      unless lst == [] do
        raise DefinitionError, "Invalid effects: #{Enum.join(lst, ", ")}"
      end
    end
  end

  defmodule Generators do
    @moduledoc false

    defmacro name(env) do
      # Yes I wanted to practice my regex skills, why do you ask?
      regex = ~r/([[:upper:]]+(?=[[:upper:]])|[[:upper:]][[:lower:]]*)/

      mod = env.module
      name = case Module.get_attribute(mod, :name) do
        nil ->
          mod_name = mod |> Atom.to_string |> String.split(".") |> Enum.at(-1)
          Regex.replace(regex, mod_name, " \\0") |> String.trim
        _ ->
          Module.get_attribute(__MODULE__, :name)
      end

      quote do
        def name, do: unquote(name)
      end
    end

    defmacro desc(env) do
      mod = env.module
      desc = Module.get_attribute(mod, :desc)
      docs = Module.get_attribute(mod, :moduledoc)

      res = case {desc, docs} do
        {desc, _} when not is_nil(desc) ->
          desc
        {nil, docs} when not is_nil(docs) ->
          docs
        _ ->
          IO.warn "Missing Component documentation"
          ""
      end

      quote do
        def desc, do: unquote(res)
      end
    end

    defmacro effects(env) do
      mod = env.module
      eff = Module.get_attribute(mod, :effects)
      eff = case eff do
        :noeffects -> []
        [el] when is_atom(el) -> [el]
        effects -> effects
      end

      quote do
        def effects, do: unquote(eff)
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
  defmacro defcomponent(name, effects, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour Skitter.Component

        # Register the effects in the module
        @effects unquote(effects)

        # Callbacks registered first will run last,
        # ensure verification happens last.
        @before_compile {Verification, :required_attributes}
        @before_compile {Verification, :effects_correct}

        # Generate callbacks for the various functions which
        # return attribute values.
        @before_compile {Generators, :name}
        @before_compile {Generators, :desc}
        @before_compile {Generators, :effects}
        @before_compile {Generators, :in_ports}
        @before_compile {Generators, :out_ports}

        # Insert the provided body
        unquote(body)
      end
    end
  end
end
