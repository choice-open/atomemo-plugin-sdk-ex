defmodule AtomemoPluginSdk.ParameterDefinition.Object do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base
  use AtomemoPluginSdk.ParameterDefinition

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "object"
    parameters :properties
    parameter :additional_properties
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          properties: [ParameterDefinition.t()],
          additional_properties: ParameterDefinition.t()
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast_parameters(:properties)
    |> cast_parameter(:additional_properties)
  end
end
