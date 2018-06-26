defmodule Skitter.Component.Behaviour do
  @moduledoc false

  @type component :: module()
  @type checkpoint :: any()
  @type instance :: Skitter.Component.Instance.t()
  @type reason :: String.t()

  @callback __skitter_metadata__ :: Skitter.Component.Metadata.t()

  @callback __skitter_init__(any()) :: {:ok, instance} | {:error, reason}
  @callback __skitter_terminate__(instance) :: :ok | {:error, reason}

  @callback __skitter_react__(instance, []) ::
              {:ok, instance, [keyword()]}
              | {:ok, nil, [keyword()]}
              | {:error, reason}
  @callback __skitter_react_after_failure__(instance, []) ::
              {:ok, instance, [keyword()]}
              | {:ok, nil, [keyword()]}
              | {:error, reason}

  @callback __skitter_create_checkpoint__(instance) ::
              {:ok, checkpoint} | :nocheckpoint
  @callback __skitter_restore_checkpoint__(checkpoint) ::
              {:ok, instance} | :nocheckpoint
  @callback __skitter_clean_checkpoint__(instance, checkpoint) ::
              :ok | :nocheckpoint
end
