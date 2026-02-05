defmodule AtomemoPluginSdk.CredentialDefinition do
  @moduledoc """
  凭证定义结构体，用于描述凭证的定义。
  """

  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    field :display_name, AtomemoPluginSdk.I18nEntry
    field :description, AtomemoPluginSdk.I18nEntry
    field :icon, :string
    parameters :parameters
  end

  @type t() :: %__MODULE__{
          name: String.t(),
          display_name: AtomemoPluginSdk.I18nEntry.t() | nil,
          description: AtomemoPluginSdk.I18nEntry.t() | nil,
          icon: String.t() | nil,
          parameters: [AtomemoPluginSdk.ParameterDefinition.t()]
        }

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:name, :display_name, :description, :icon])
    |> validate_required([:name])
    |> cast_parameters(:parameters)
  end
end
