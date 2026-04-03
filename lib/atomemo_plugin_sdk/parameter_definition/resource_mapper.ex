defmodule AtomemoPluginSdk.ParameterDefinition.ResourceMapper do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: false

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "resource_mapper"
    field :mapping_method, :string
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          mapping_method: String.t()
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:mapping_method])
    |> validate_required([:mapping_method])
    |> validate_default_if_needed()
  end
end
