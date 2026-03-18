defmodule AtomemoPluginSdk.ToolDefinition do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  alias AtomemoPluginSdk.{I18nEntry, NameValidator, ResourceMapperSchemaField}

  @derive {JSON.Encoder, except: [:invoke, :locator_list, :resource_mapping]}
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
    field :locator_list, :map, default: %{}
    field :resource_mapping, :map, default: %{}

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
          locator_list: %{optional(String.t()) => locator_list_fn()},
          resource_mapping: %{optional(String.t()) => resource_mapping_fn()},
          parameters: [ParameterDefinition.t()],
          settings: [ParameterDefinition.t()]
        }

  @type locator_list_fn() :: (%{
                                filter: String.t() | nil,
                                pagination_token: String.t() | nil,
                                parameters: map(),
                                credentials: map()
                              } ->
                                {:ok,
                                 %{
                                   results: [
                                     %{
                                       label: String.t(),
                                       value: String.t(),
                                       url: String.t() | nil
                                     }
                                   ],
                                   pagination_token: String.t() | nil
                                 }}
                                | {:error, map()})

  @type resource_mapping_fn() :: (%{parameters: map(), credentials: map()} ->
                                    {:ok,
                                     %{
                                       fields: [ResourceMapperSchemaField.t()],
                                       empty_fields_notice: I18nEntry.t() | nil
                                     }}
                                    | {:error, map()})

  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [
      :name,
      :display_name,
      :description,
      :icon,
      :timeout,
      :skill,
      :invoke,
      :locator_list,
      :resource_mapping
    ])
    |> validate_required([:name])
    |> NameValidator.validate_name()
    |> cast_parameters(:parameters)
    |> cast_parameters(:settings)
  end
end
