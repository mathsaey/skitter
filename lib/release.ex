# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Release do
  @moduledoc """
  Utilities for building Skitter releases.

  Releases (`mix release`) are used to deploy Skitter applications over a cluster. Skitter
  includes several configuration files and scripts to customize the generated release and to
  faciliate its distribution. In order for your application to use these scripts, your release
  configuration should use the `step/1` function defined in this module:

  ```
  def project do
    ...,
    releases: [
      <your_release_name>: [steps: [&Skitter.Release.step/1, :assemble]]
    ],
    ...
  end
  ```

  This will cause Skitter to customize the configuration of your release to include the required
  configuration files and scripts.

  Please refer to the [deployment page](deployment.html#releases) for more information about Skitter
  releases and how to use them.
  """

  @doc """
  Customize the release assembly.

  This function customizes the configuration of a release to include several Skitter configuration
  files and scripts. Concretely, it makes the following modifications:

  - Modify the release to only include unix executables.
  - Add Skitter-specific `env.sh.eex` and `vm.args` files.
  - Add the `skitter` deploy script used to manage Skitter runtime systems.
  - Adds a `skitter.exs` script which is used to configure the Skitter runtime based on
    environment variables before it starts.

  This function should be added to the `steps` configuration of your release __before__ the
  `:assemble` step. It is best to include it after any other steps, as this enables the function
  to verify that the Skitter generated configuration does not overwrite user-provided
  configuration values.

  The following assumptions about your release configuration are made:

  - The `:include_executables_for` option is not set. Instead, it is set to `[:unix]`.
  - The `:rel_templates_path` option is not set. Instead, it is set to point to a directory
    containing Skitter specific `env.sh.eex` and `vm.args.eex` files.
  """
  def step(rel) do
    rel
    |> override_options()
    |> add_skitter_deploy_script()
    |> add_skitter_runtime_config()
  end

  # We override the following options:
  #   - include_executables_for: we only provide unix deployment and management scripts, so only
  #     allow the release to be built for unix.
  #   - rel_templates_path: we provide our own vm.args and env.sh.eex inside the "rel" directory.
  defp override_options(r = %Mix.Release{options: opts}) do
    opts =
      opts
      |> put_new!(:include_executables_for, [:unix])
      |> put_new!(:rel_templates_path, Path.join([__DIR__, "release", "rel"]))

    %{r | options: opts}
  end

  # Add a script which is responsible for managing skitter runtimes and deploying it over a
  # cluster.
  defp add_skitter_deploy_script(r = %Mix.Release{steps: steps}) do
    %{r | steps: add_after_assemble(steps, &copy_skitter_deploy_script/1)}
  end

  defp copy_skitter_deploy_script(r = %Mix.Release{path: path}) do
    target = Path.join([path, "bin", "skitter"])

    Mix.Generator.copy_template(
      Path.join([__DIR__, "release", "skitter.sh.eex"]),
      target,
      [release: r, version: Application.spec(:skitter, :vsn)],
      force: true
    )

    File.chmod!(target, 0o744)

    r
  end

  # Include a script that configures the skitter runtime based on environment variables when a
  # release is started.
  defp add_skitter_runtime_config(r = %Mix.Release{config_providers: providers, steps: steps}) do
    config = {:system, "RELEASE_ROOT", "/releases/#{r.version}/skitter.exs"}
    steps = add_after_assemble(steps, &copy_skitter_runtime_config/1)
    %{r | config_providers: [{Config.Reader, config} | providers], steps: steps}
  end

  defp copy_skitter_runtime_config(r = %Mix.Release{version_path: path}) do
    File.cp!(Path.join([__DIR__, "release/skitter.exs"]), Path.join(path, "skitter.exs"))
    r
  end

  defp put_new!(kw, k, v) do
    if Keyword.has_key?(kw, k) do
      Mix.raise("Value found for Skitter defined configuration: #{k}")
    else
      Keyword.put(kw, k, v)
    end
  end

  defp add_after_assemble(steps, step) do
    idx = Enum.find_index(steps, &(&1 == :assemble))
    List.insert_at(steps, idx + 1, step)
  end
end
