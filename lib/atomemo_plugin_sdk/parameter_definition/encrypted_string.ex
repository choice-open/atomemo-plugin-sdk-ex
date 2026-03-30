defmodule AtomemoPluginSdk.ParameterDefinition.EncryptedString do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: false

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "encrypted_string"
  end

  @type t() :: %__MODULE__{
          type: String.t()
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
  end
end
