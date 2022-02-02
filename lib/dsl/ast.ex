# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.AST do
  @moduledoc false
  # Private ast transformations for use in DSLs

  @doc """
  Convert a name AST into an atom.
  """
  def name_to_atom({name, _, a}) when is_atom(name) and is_atom(a), do: name

  @doc """
  Convert a list of AST names into a list of atoms using `name_to_atom/2`
  """
  def names_to_atoms(lst) when is_list(lst), do: Enum.map(lst, &name_to_atom/1)
  def names_to_atoms(any), do: names_to_atoms([any])
end
