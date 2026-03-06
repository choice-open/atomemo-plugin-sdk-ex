defmodule AtomemoPluginSdk.Context do
  @derive {JSON.Encoder, only: [:organization_id]}

  defstruct [:__hub_client__, :organization_id]

  @type t :: %__MODULE__{
          __hub_client__: pid() | atom(),
          organization_id: String.t()
        }
end
