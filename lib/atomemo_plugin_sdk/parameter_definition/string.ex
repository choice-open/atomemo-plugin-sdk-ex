defmodule AtomemoPluginSdk.ParameterDefinition.String do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "string"
    field :max_length, :integer
    field :min_length, :integer
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          max_length: integer() | nil,
          min_length: integer() | nil
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:max_length, :min_length])
    |> validate_number(:max_length, greater_than_or_equal_to: 0)
    |> validate_number(:min_length, greater_than_or_equal_to: 0)
    |> validate_max_length_gte_min_length()
  end

  defp validate_max_length_gte_min_length(changeset) do
    min_length = get_field(changeset, :min_length)
    max_length = get_field(changeset, :max_length)

    if min_length && max_length && max_length < min_length do
      add_error(changeset, :max_length, "max_length must be greater than or equal to min_length")
    else
      changeset
    end
  end
end
