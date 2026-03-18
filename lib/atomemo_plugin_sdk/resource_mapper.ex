defmodule AtomemoPluginSdk.ResourceMapper do
  @moduledoc """
  Runtime resource mapper value struct.

  Represents the runtime value of a resource_mapper parameter, containing:
  - `mapping_mode`: :auto or :manual
  - `value`: when manual, the mapping object (map); nil for auto mode
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :mapping_mode, Ecto.Enum, values: [:auto, :manual]
    # NOTE In JS SDK the 'value' is string or object.
    # String is for workflow expression in runtime and can't happen in Hub and Elixir SDK.
    # Value as expression is also not allowed in parameter definition.
    # So we use map here.
    field :value, :map
  end

  @type t() :: %__MODULE__{
          mapping_mode: :auto | :manual,
          value: map() | nil
        }

  def hydrate_changeset(resource_mapper \\ %__MODULE__{}, attrs) do
    resource_mapper
    |> cast(attrs, [:mapping_mode, :value])
    |> validate_required([:mapping_mode])
  end

  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    changeset = hydrate_changeset(%__MODULE__{}, attrs)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      [{field, {msg, _opts}} | _] = changeset.errors
      {:error, "#{field} #{msg}"}
    end
  end

  def new(_), do: {:error, "not a map"}

  @spec new!(map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, message} -> raise ArgumentError, "Invalid ResourceMapper: #{message}"
    end
  end
end

defimpl JSON.Encoder, for: AtomemoPluginSdk.ResourceMapper do
  def encode(%@for{} = resource_mapper, _encoder) do
    resource_mapper
    |> Map.from_struct()
    |> Map.put(:__type__, "resource_mapper")
    |> Map.put(:mapping_mode, Atom.to_string(resource_mapper.mapping_mode))
    |> JSON.encode_to_iodata!()
  end
end
