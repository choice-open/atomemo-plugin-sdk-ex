defmodule AtomemoPluginSdk.ModelDefinition do
  @moduledoc """
  模型定义结构体，对应 JS SDK 中的 `ModelDefinition`。
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AtomemoPluginSdk.I18nEntry

  @model_type_values [:llm]
  @input_modality_values [:file, :image, :text]
  @output_modality_values [:text]

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    # BaseDefinition 公共字段
    field :name, :string
    field :display_name, I18nEntry
    field :description, I18nEntry
    field :icon, :string

    # ModelDefinition 特有字段
    field :model_type, Ecto.Enum, values: @model_type_values, default: :llm
    field :default_endpoint, :string
    field :input_modalities, {:array, Ecto.Enum}, values: @input_modality_values
    field :output_modalities, {:array, Ecto.Enum}, values: @output_modality_values
    field :pricing, :map
    field :override_parameters, :map
    field :unsupported_parameters, {:array, :string}, default: []
  end

  @type model_type() :: :llm
  @type input_modality() :: :file | :image | :text
  @type output_modality() :: :text

  @type t() :: %__MODULE__{
          name: String.t(),
          display_name: I18nEntry.t() | nil,
          description: I18nEntry.t() | nil,
          icon: String.t() | nil,
          model_type: model_type(),
          default_endpoint: String.t() | nil,
          input_modalities: [input_modality()],
          output_modalities: [output_modality()],
          pricing: map() | nil,
          override_parameters: map() | nil,
          unsupported_parameters: [String.t()]
        }

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [
      :name,
      :display_name,
      :description,
      :icon,
      :model_type,
      :default_endpoint,
      :input_modalities,
      :output_modalities,
      :pricing,
      :override_parameters,
      :unsupported_parameters
    ])
    |> validate_required([
      :name,
      :display_name,
      :description,
      :icon,
      :model_type,
      :input_modalities,
      :output_modalities
    ])
    |> validate_model_name()
  end

  defp validate_model_name(changeset) do
    validate_format(
      changeset,
      :name,
      ~r/^[a-zA-Z](?:(?![_-]{2,})[a-zA-Z0-9_\/-]){3,63}[a-zA-Z0-9]$/,
      message:
        "must start with a letter, end with a letter or number, cannot contain consecutive underscores or hyphens, allow '/' in the middle"
    )
  end
end
