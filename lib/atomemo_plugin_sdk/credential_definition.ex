defmodule AtomemoPluginSdk.CredentialDefinition do
  @moduledoc """
  Credential definition struct, used to describe a credential and how to
  authenticate with it.
  """

  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  @derive {JSON.Encoder, except: [:authenticate]}
  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    field :display_name, AtomemoPluginSdk.I18nEntry
    field :description, AtomemoPluginSdk.I18nEntry
    field :icon, :string
    # Non-serialized field for performing authentication / building auth_spec
    field :authenticate, :any, virtual: true
    parameters :parameters
  end

  @type t() :: %__MODULE__{
          name: String.t(),
          display_name: AtomemoPluginSdk.I18nEntry.t() | nil,
          description: AtomemoPluginSdk.I18nEntry.t() | nil,
          icon: String.t() | nil,
          parameters: [AtomemoPluginSdk.ParameterDefinition.t()],
          authenticate: authenticate_fun()
        }

  @type authenticate_fun() :: (args :: map() -> {:ok, map()} | {:error, any()})

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:name, :display_name, :description, :icon, :authenticate])
    |> validate_required([:name])
    |> cast_parameters(:parameters)
  end
end
