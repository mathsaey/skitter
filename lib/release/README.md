# Release

The files in this directory are used when building releases of a Skitter. More
information can be found in the module doc of `lib/release.ex`. The following
files are present:

- `skitter.sh.exs`: The Skitter deployment script. This script is responsible
  for setting the required environment variables before a Skitter release is
  started. The script is added to each Skitter release as `bin/skitter`.
- `skitter.exs`: This script is added to each Skitter release as a config
  reader. It sets up the application environment of the Skitter application
  based on the environment variables set by the skitter deploy script.
- `config.ex`: This module defines abstractions used by `skitter.exs`.
- `rel`: This directory contains the `env.sh` and `vm.args` files added to
  Skitter releases. More information about these files can be found in the
  [Elixir release documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-vm-args-and-env-sh-env-bat).
