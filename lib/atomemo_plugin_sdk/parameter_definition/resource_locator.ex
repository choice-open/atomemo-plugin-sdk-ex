defmodule AtomemoPluginSdk.ParameterDefinition.ResourceLocator.ListMode do
  use Ecto.Schema

  import Ecto.Changeset

  alias AtomemoPluginSdk.I18nEntry

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :type, :string, default: "list"
    field :display_name, I18nEntry
    field :placeholder, I18nEntry
    field :search_list_method, :string
    field :searchable, :boolean, default: false
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          display_name: I18nEntry.t() | nil,
          placeholder: I18nEntry.t() | nil,
          search_list_method: String.t(),
          searchable: boolean() | nil
        }

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:type, :display_name, :placeholder, :search_list_method, :searchable])
    |> validate_required([:type, :search_list_method])
  end
end

defmodule AtomemoPluginSdk.ParameterDefinition.ResourceLocator.UrlMode do
  use Ecto.Schema

  import Ecto.Changeset

  alias AtomemoPluginSdk.I18nEntry

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :type, :string, default: "url"
    field :display_name, I18nEntry
    field :placeholder, I18nEntry
    field :extract_value, :map
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          display_name: I18nEntry.t() | nil,
          placeholder: I18nEntry.t() | nil,
          extract_value: map() | nil
        }

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:type, :display_name, :placeholder, :extract_value])
    |> validate_required([:type])
  end
end

defmodule AtomemoPluginSdk.ParameterDefinition.ResourceLocator.IdMode do
  use Ecto.Schema

  import Ecto.Changeset

  alias AtomemoPluginSdk.I18nEntry

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :type, :string, default: "id"
    field :display_name, I18nEntry
    field :placeholder, I18nEntry
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          display_name: I18nEntry.t() | nil,
          placeholder: I18nEntry.t() | nil
        }

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:type, :display_name, :placeholder])
    |> validate_required([:type])
  end
end

defmodule AtomemoPluginSdk.ParameterDefinition.ResourceLocator do
  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition.Base

  import Ecto.Changeset
  import PolymorphicEmbed

  alias __MODULE__.{ListMode, UrlMode, IdMode}

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    base_schema()
    field :type, :string, default: "resource_locator"

    polymorphic_embeds_many :modes,
      type_field_name: :type,
      on_replace: :delete,
      types: [list: ListMode, url: UrlMode, id: IdMode]
  end

  @type t() :: %__MODULE__{
          type: String.t(),
          modes: [ListMode.t() | UrlMode.t() | IdMode.t()]
        }

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast_and_validate_base_fields(attrs)
    |> cast_polymorphic_embed(:modes, required: true)
    |> validate_modes_not_empty()
  end

  defp validate_modes_not_empty(changeset) do
    modes = get_field(changeset, :modes) || []

    if modes == [] do
      add_error(changeset, :modes, "must have at least one mode")
    else
      changeset
    end
  end
end
