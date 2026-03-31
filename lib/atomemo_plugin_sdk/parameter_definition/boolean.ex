defmodule AtomemoPluginSdk.ParameterDefinition.Boolean do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "boolean"
  end

  @type t() :: %__MODULE__{
          type: String.t()
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> validate_default_if_needed()
  end
end
