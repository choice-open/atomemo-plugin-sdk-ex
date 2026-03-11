defmodule AtomemoPluginSdk.FileRef do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Runtime file reference struct, shared by Hub and SDK.

  - `source`: `:oss` (object storage) or `:mem` (in-memory)
  - `content`: raw binary; when `source` is `:mem` this holds the file bytes
  - JSON encoding adds `__type__: "file_ref"` and base64-encodes `content`
  """

  @type t :: %__MODULE__{
          source: :oss | :mem,
          filename: String.t() | nil,
          extension: String.t() | nil,
          mime_type: String.t() | nil,
          size: non_neg_integer() | nil,
          res_key: String.t() | nil,
          remote_url: String.t() | nil,
          content: binary() | nil
        }

  @field_specs [
    {:source, Ecto.Enum, [values: [:oss, :mem]]},
    {:filename, :string, []},
    {:extension, :string, []},
    {:mime_type, :string, []},
    {:size, :integer, []},
    {:res_key, :string, []},
    {:remote_url, :string, []},
    {:content, :binary, []}
  ]

  @fields Enum.map(@field_specs, &elem(&1, 0))

  @primary_key false
  embedded_schema do
    for {name, type, opts} <- @field_specs do
      field(name, type, opts)
    end
  end

  def hydrate_changeset(file_ref \\ %__MODULE__{}, attrs) do
    file_ref
    |> cast(attrs, @fields)
    |> validate_required([:source])
    |> decode_content_if_needed()
  end

  defp decode_content_if_needed(chset) do
    case get_change(chset, :content) do
      nil -> chset
      content -> put_change(chset, :content, Base.decode64!(content))
    end
  end

  @doc """
  Builds a FileRef struct from a map (e.g. from JSON with string keys).

  Validates all fields; does not assume JSON is well-formed.
  Returns `{:ok, struct}` or `{:error, message}` with a string message.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, source} <- validate_source(attrs["source"]),
         {:ok, content} <- validate_content(attrs["content"]),
         :ok <- validate_optional_string(attrs, "filename"),
         :ok <- validate_optional_string(attrs, "extension"),
         :ok <- validate_optional_string(attrs, "mime_type"),
         :ok <- validate_optional_string(attrs, "res_key"),
         :ok <- validate_optional_string(attrs, "remote_url"),
         {:ok, size} <- validate_size(attrs["size"]) do
      {:ok,
       %__MODULE__{
         source: source,
         filename: attrs["filename"],
         extension: attrs["extension"],
         mime_type: attrs["mime_type"],
         size: size,
         res_key: attrs["res_key"],
         remote_url: attrs["remote_url"],
         content: content
       }}
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
      {:error, message} -> raise ArgumentError, "Invalid FileRef: #{message}"
    end
  end

  defp validate_source("oss"), do: {:ok, :oss}
  defp validate_source("mem"), do: {:ok, :mem}
  defp validate_source(nil), do: {:error, "source is required"}
  defp validate_source(other), do: {:error, "invalid source: #{inspect(other)}"}

  defp validate_content(nil), do: {:ok, nil}
  defp validate_content(b) when not is_binary(b), do: {:error, "content must be binary"}

  defp validate_content(b) do
    case Base.decode64(b) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, "invalid base64 content"}
    end
  end

  defp validate_optional_string(attrs, key) do
    case attrs[key] do
      nil -> :ok
      s when is_binary(s) -> :ok
      _ -> {:error, "invalid field: #{key}"}
    end
  end

  defp validate_size(nil), do: {:ok, nil}
  defp validate_size(n) when not is_integer(n), do: {:error, "size must be integer"}
  defp validate_size(n) when n < 0, do: {:error, "size must be non-negative"}
  defp validate_size(n), do: {:ok, n}
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
