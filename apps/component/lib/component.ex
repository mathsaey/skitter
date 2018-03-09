defmodule Skitter.Component do
  @moduledoc """
  A module to implement and verify Skitter components.
  """

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
    # TODO: Check if effects are valid

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
      nil
    end
  end

  defmodule Generators do
    @moduledoc false

    @doc """
    Generate a `name` function for the component module.

    If an @name attribute is provided, it will be used.
    Otherwise, a name is generated from the macro name.
    This name is the final part of the component module name, with spaces
    inserted before every uppercase letter.

    Thus, a component with module name "Foo.HelloWorld" would get the name
    "Hello World".
    Acronyms in such a name are kept "whole", a module named "IOPuts" would be
    named "IO Puts".
    """
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
      quote do
        def effects, do: unquote(Module.get_attribute(env.module, :effects))
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

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Skitter.Component

      # Register the effects in the module
      @effects unquote(Keyword.get(opts, :effects))

      # Callbacks registered first will run last,
      # ensure verification happens last.
      @before_compile {Verification, :required_attributes}

      # Generate callbacks for the various functions which
      # return attribute values.
      @before_compile {Generators, :name}
      @before_compile {Generators, :desc}
      @before_compile {Generators, :effects}
      @before_compile {Generators, :in_ports}
      @before_compile {Generators, :out_ports}
    end
  end

  # TODO: Document this
  defmacro defcomponent(name, effects, do: body) do
    quote do
      defmodule unquote(name) do
        use Skitter.Component, effects: unquote(effects)
        unquote(body)
      end
    end
  end
end
