defmodule AtomemoPluginSdk.ResourceLocator do
  @moduledoc """
  Runtime resource locator value struct.

  Represents the runtime value of a resource_locator parameter, containing:
  - `mode_name`: the mode used to locate the resource (:list, :url, :id)
  - `value`: the actual value (e.g., resource ID, URL string)
  - `cached_result_label`: optional cached display label for the resolved resource
  - `cached_result_url`: optional cached URL for the resolved resource
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :mode_name, Ecto.Enum, values: [:list, :url, :id]
    field :value, :string
    field :cached_result_label, :string
    field :cached_result_url, :string
  end

  @type t() :: %__MODULE__{
          mode_name: :list | :url | :id,
          value: String.t() | nil,
          cached_result_label: String.t() | nil,
          cached_result_url: String.t() | nil
        }

  def hydrate_changeset(resource_locator \\ %__MODULE__{}, attrs) do
    resource_locator
    |> cast(attrs, [:mode_name, :value, :cached_result_label, :cached_result_url])
    |> validate_required([:mode_name])
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
      {:error, message} -> raise ArgumentError, "Invalid ResourceLocator: #{message}"
    end
  end

  @doc """
  Returns a map suitable for JSON/DB serialization (string keys, mode_name as string).
  Used by JSON.Encoder and TypedParameters.
  """
  @spec to_serializable_map(t()) :: map()
  def to_serializable_map(%__MODULE__{} = rl) do
    %{
      "__type__" => "resource_locator",
      "mode_name" => Atom.to_string(rl.mode_name),
      "value" => rl.value,
      "cached_result_label" => rl.cached_result_label,
      "cached_result_url" => rl.cached_result_url
    }
  end
end

defimpl JSON.Encoder, for: AtomemoPluginSdk.ResourceLocator do
  def encode(resource_locator, _encoder) do
    resource_locator
    |> @for.to_serializable_map()
    |> JSON.encode_to_iodata!()
  end
end
