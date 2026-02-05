defmodule AtomemoPluginSdk.ParameterDefinition.Array do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "array"
    field :max_items, :integer
    field :min_items, :integer
    parameter :items
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          max_items: integer() | nil,
          min_items: integer() | nil,
          items: ParameterDefinition.t() | nil
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:max_items, :min_items])
    |> validate_number(:max_items, greater_than_or_equal_to: 0)
    |> validate_number(:min_items, greater_than_or_equal_to: 0)
    |> validate_max_items_gte_min_items()
    |> cast_parameter(:items)
  end

  defp validate_max_items_gte_min_items(changeset) do
    min_items = get_field(changeset, :min_items)
    max_items = get_field(changeset, :max_items)

    if min_items && max_items && max_items < min_items do
      add_error(changeset, :max_items, "max_items must be greater than or equal to min_items")
    else
      changeset
    end
  end
end
