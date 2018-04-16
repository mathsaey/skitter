defmodule Skitter.Component do
  @moduledoc """
  """

  # ---------------- #
  # Using Components #
  # ---------------- #

  @doc """
  Returns the name of a component.

  The name of a component is automatically generated based on the component
  name provided to `component/3`.
  """
  def name(comp), do: comp.__skitter_metadata__.name

  @doc """
  Returns the description of a component.

  The description of a component can be provided by adding a string as the first
  element of the `component/3` body.
  An empty string is returned if no documentation is present.

  ## Example

  ```
  component Example, in: [:in], out: [:out] do
    "Your description goes here"
  end
  ```
  """
  def description(comp), do: comp.__skitter_metadata__.description

  @doc """
  Return the effects of a component.

  TODO: Add more information about this later.
  """
  def effects(comp), do: comp.__skitter_metadata__.effects

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def in_ports(comp), do: comp.__skitter_metadata__.in_ports

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def out_ports(comp), do: comp.__skitter_metadata__.out_ports

  # -------------------- #
  # Component Generation #
  # -------------------- #

  @doc """
  Create a skitter component.
  """
  defmacro component(name, ports, do: body) do
    full_name = full_name(Macro.expand(name, __CALLER__))
    {in_ports, out_ports} = read_ports(ports)
    {desc, body} = extract_description(body)

    quote do
      defmodule unquote(name) do
        import unquote(__MODULE__), only: [effect: 2, effect: 1]

        # Store component metadata
        Module.put_attribute __MODULE__, :skitter_name, unquote(full_name)
        Module.put_attribute __MODULE__, :skitter_description, unquote(desc)
        Module.put_attribute __MODULE__, :skitter_in_ports, unquote(in_ports)
        Module.put_attribute __MODULE__, :skitter_out_ports, unquote(out_ports)

        # Effects will be added by the effects macro
        Module.register_attribute __MODULE__, :skitter_effects, accumulate: true

        # Precompile step to generate the __skitter_metadata__ function
        @before_compile {unquote(__MODULE__), :__generate_metadata__}

        unquote(body)
      end
    end
  end

  # Internal Macros
  # ---------------
  # Macros to be used inside component/3

  @doc """
  Specify an effect of the current component.
  """
  defmacro effect(name, properties \\ []) do
    quote do @skitter_effects {unquote(name), unquote(properties)} end
  end

  # Utility Functions
  # -----------------

  # Generate a readable string (i.e. a string with spaces) based on the name
  # of a component.
  defp full_name(name) do
    regex = ~r/([[:upper:]]+(?=[[:upper:]]|$)|[[:upper:]][[:lower:]]*)/
    name  = name |> Atom.to_string |> String.split(".") |> Enum.at(-1)
    Regex.replace(regex, name, " \\0") |> String.trim
  end

  # Verify the ports keyword list
  # TODO: expand on this later:
  #   - Allow a single port instead of a full list
  #   - Throw errors when the list is in the wrong format
  defp read_ports([in: in_ports, out: out_ports]) do
    {in_ports, out_ports}
  end

  # Retrieve the description from a component if it is present.
  # A description is provided when the component body start with a string.
  # If this is the case, remove the string from the body and use it as the
  # component description.
  # If it is not the case, leave the component body untouched.
  defp extract_description({:__block__, env, [str | r]}) when is_binary(str) do
    {str, {:__block__, env, r}}
  end
  defp extract_description(str) when is_binary(str), do: {str, quote do end}
  defp extract_description(any), do: {"", any}

  defmacro __generate_metadata__(env) do
    mod = env.module
    quote do
      def __skitter_metadata__ do
        %{
          name: unquote(Module.get_attribute(mod, :skitter_name)),
          effects: unquote(Module.get_attribute(mod, :skitter_effects)),
          in_ports: unquote(Module.get_attribute(mod, :skitter_in_ports)),
          out_ports: unquote(Module.get_attribute(mod, :skitter_out_ports)),
          description: unquote(Module.get_attribute(mod, :skitter_description))
        }
      end
    end
  end

  # ----------------- #
  # Auxiliary Modules #
  # ----------------- #

  defmodule DefinitionError do
    @moduledoc """
    This error is raised when a component definition is invalid.
    """
    defexception [:message]

    def exception(val) do
      %DefinitionError{message: val}
    end
  end

  defmodule BadCallError do
    @moduledoc """
    This error is raised when a function is called on a component that does not
    support it (due to its effects)
    """
    defexception [:message]

    def exception(val) do
      %BadCallError{message: val}
    end
  end
end
