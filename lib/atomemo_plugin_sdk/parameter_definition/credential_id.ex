defmodule AtomemoPluginSdk.ParameterDefinition.CredentialId do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: false

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "credential_id"
    field :credential_name, :string
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          credential_name: String.t() | nil
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:credential_name])
    |> validate_required([:credential_name])
    |> validate_default_if_needed()
  end
end
