defmodule AtomemoPluginSdk.ParameterDefinition.Number do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "number"
    field :maximum, :float
    field :minimum, :float
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          maximum: float() | nil,
          minimum: float() | nil
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:maximum, :minimum])
    |> validate_maximum_gte_minimum()
    |> validate_default_if_needed()
  end

  defp validate_maximum_gte_minimum(changeset) do
    maximum = get_field(changeset, :maximum)
    minimum = get_field(changeset, :minimum)

    if maximum && minimum && maximum < minimum do
      add_error(changeset, :maximum, "maximum must be greater than or equal to minimum")
    else
      changeset
    end
  end
end
