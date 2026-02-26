defmodule AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "discriminated_union"
    field :discriminator, :string
    field :discriminator_ui, :map
    parameters :any_of
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          discriminator: String.t() | nil,
          discriminator_ui: map() | nil,
          any_of: [ParameterDefinition.Object.t()]
        }

  def changeset(changeset, attrs) do
    changeset
    |> cast_and_validate_base_fields(attrs)
    |> cast(attrs, [:discriminator, :discriminator_ui])
    |> validate_required([:discriminator])
    |> cast_parameters(:any_of)
    |> validate_any_of_required()
  end

  defp validate_any_of_required(changeset) do
    any_of = get_field(changeset, :any_of)

    if any_of && length(any_of) > 0 do
      changeset
    else
      add_error(changeset, :any_of, "any_of must contain at least one object type")
    end
  end
end
