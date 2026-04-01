defmodule AtomemoPluginSdk.FileRef do
  use Ecto.Schema
  import Ecto.Changeset

  alias AtomemoPluginSdk.ParameterError, as: Error

  @moduledoc """
  Runtime file reference struct, shared by Hub and SDK.

  - `source`: `:oss` (object storage) or `:mem` (in-memory)
  - `content`: raw binary; when `source` is `:mem` this holds the file bytes
  - JSON encoding adds `__type__: "file_ref"` and base64-encodes `content`
  """

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :source, Ecto.Enum, values: [:oss, :mem]
    field :filename, :string
    field :extension, :string
    field :mime_type, :string
    field :size, :integer
    field :res_key, :string
    field :remote_url, :string
    field :content, :binary
  end

  def changeset(file_ref \\ %__MODULE__{}, attrs) do
    file_ref
    |> cast(attrs, [
      :source,
      :filename,
      :extension,
      :mime_type,
      :size,
      :res_key,
      :remote_url,
      :content
    ])
    |> validate_required([:source])
    |> validate_number(:size, greater_than_or_equal_to: 0)
  end

  def hydrate_changeset(file_ref \\ %__MODULE__{}, attrs) do
    file_ref
    |> changeset(attrs)
    |> decode_content_if_needed()
  end

  @doc """
  Builds a FileRef struct from a map (e.g. from JSON with string keys).

  Validates all fields; does not assume JSON is well-formed.
  Returns `{:ok, struct}` or `{:error, message}` with a string message.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    case attrs |> changeset() |> apply_action(:insert) do
      {:ok, file_ref} -> {:ok, file_ref}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def new(_), do: {:error, "not a map"}

  @doc """
  Like `new/1` but raises on invalid input.
  """
  @spec new!(map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, changeset} -> raise Error.new(changeset, source: :runtime)
    end
  end

  defp decode_content_if_needed(chset) do
    case get_change(chset, :content) do
      nil ->
        chset

      content ->
        case Base.decode64(content) do
          {:ok, decoded} -> put_change(chset, :content, decoded)
          :error -> add_error(chset, :content, "invalid base64 content")
        end
    end
  end
end

defimpl JSON.Encoder, for: AtomemoPluginSdk.FileRef do
  def encode(%@for{} = file_ref, _encoder) do
    file_ref
    |> Map.from_struct()
    |> Map.put_new(:__type__, "file_ref")
    |> Map.put(:source, Atom.to_string(file_ref.source))
    |> Map.put(:content, file_ref.content && Base.encode64(file_ref.content))
    |> JSON.encode_to_iodata!()
  end
end
