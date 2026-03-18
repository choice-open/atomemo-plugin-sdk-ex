defmodule AtomemoPluginSdk.ResourceMapperSchemaField do
  @moduledoc """
  Resource mapper schema field struct.

  NOTE This struct is used as result of tool invoke. It's used in parameter hydration.
  """
  use Ecto.Schema

  alias AtomemoPluginSdk.I18nEntry

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :id, :string
    field :type, Ecto.Enum, values: [:string, :number, :integer, :boolean, :object, :array]
    field :display_name, I18nEntry
    field :required, :boolean, default: false
  end

  @type t() :: %__MODULE__{
          id: String.t(),
          type: :string | :number | :integer | :boolean | :object | :array,
          display_name: I18nEntry.t() | nil,
          required: boolean() | nil
        }
end
