defmodule AtomemoPluginSdk.ToolDefinition do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  alias AtomemoPluginSdk.{I18nEntry, NameValidator}

  @derive {JSON.Encoder, except: [:invoke]}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :display_name, I18nEntry
    field :description, I18nEntry
    field :icon, :string
    field :timeout, :integer
    field :skill, :string

    # 不会被序列化的属性，用于调用工具的函数
    field :invoke, :any, virtual: true

    parameters :parameters
    parameters :settings
  end

  @type t() :: %__MODULE__{
          name: String.t(),
          display_name: I18nEntry.t() | nil,
          description: I18nEntry.t() | nil,
          icon: String.t() | nil,
          skill: String.t() | nil,
          invoke: (map() -> {:ok, any()} | {:error, any()}) | nil,
          parameters: [ParameterDefinition.t()],
          settings: [ParameterDefinition.t()]
        }

  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :display_name, :description, :icon, :timeout, :skill, :invoke])
    |> validate_required([:name])
    |> NameValidator.validate_name()
    |> cast_parameters(:parameters)
    |> cast_parameters(:settings)
  end
end
