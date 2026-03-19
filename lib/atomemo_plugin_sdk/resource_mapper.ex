defmodule AtomemoPluginSdk.ResourceMapper do
  @moduledoc """
  Runtime resource mapper value struct.

  Represents the runtime value of a resource_mapper parameter, containing:
  - `mapping_mode`: :auto or :manual
  - `value`: when manual, the mapping object (map); nil for auto mode
  """
  alias AtomemoPluginSdk.JSONValue
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
          value: JSONValue.object() | nil
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

  @doc """
  Returns a map suitable for JSON/DB serialization (string keys, mapping_mode as string).
  Used by JSON.Encoder and TypedParameters.
  """
  @spec to_serializable_map(t()) :: map()
  def to_serializable_map(%__MODULE__{} = rm) do
    %{
      "__type__" => "resource_mapper",
      "mapping_mode" => Atom.to_string(rm.mapping_mode),
      "value" => rm.value
    }
  end
end

defimpl JSON.Encoder, for: AtomemoPluginSdk.ResourceMapper do
  def encode(resource_mapper, _encoder) do
    resource_mapper
    |> @for.to_serializable_map()
    |> JSON.encode_to_iodata!()
  end
end
