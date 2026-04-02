defmodule AtomemoPluginSdk.ParameterError do
  @moduledoc false

  defmodule Entry do
    @moduledoc false

    @type segment :: String.t() | non_neg_integer()
    @type path_like :: segment() | atom() | [segment() | atom()]

    @type t() :: %__MODULE__{path: [segment()], message: String.t()}

    @derive JSON.Encoder
    defstruct [:path, :message]

    @spec new(String.t() | Ecto.Changeset.t(), path: path_like, prefix: path_like) :: [t()]
    def new(message_or_changeset, opts \\ [])

    def new(message, opts) when is_binary(message) do
      path = Keyword.get(opts, :path) || []
      prefix = Keyword.get(opts, :prefix) || []

      [
        %__MODULE__{path: normalize_path(prefix) ++ normalize_path(path), message: message}
      ]
    end

    def new(%Ecto.Changeset{} = changeset, opts) do
      prefix = Keyword.get(opts, :prefix) || []

      changeset
      |> PolymorphicEmbed.traverse_errors(fn {message, opts} ->
        Enum.reduce(opts, message, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", inspect(value))
        end)
      end)
      |> build_error_details()
      |> Enum.map(fn %{path: path, message: message} ->
        %__MODULE__{
          path: normalize_path(prefix) ++ normalize_path(path),
          message: message
        }
      end)
    end

    @spec normalize_path(path_like()) :: [segment()]
    def normalize_path(path) when is_list(path), do: Enum.map(path, &normalize_segment/1)
    def normalize_path(path), do: [normalize_segment(path)]

    defp normalize_segment(segment) when is_atom(segment), do: Atom.to_string(segment)
    defp normalize_segment(segment), do: segment

    defp build_error_details(error_map, path \\ [], acc \\ []) do
      Enum.reduce(error_map, acc, fn
        {key, [msg | _] = msgs}, acc when is_binary(msg) ->
          for msg <- msgs, reduce: acc do
            acc ->
              item = %{
                path: Enum.reverse([key | path]),
                message: msg
              }

              [item | acc]
          end

        {key, sub_error_map}, acc when is_map(sub_error_map) ->
          build_error_details(sub_error_map, [key | path], acc)

        {key, [%{} | _] = sub_error_maps}, acc ->
          for {sub_error_map, idx} <- Enum.with_index(sub_error_maps),
              map_size(sub_error_map) > 0,
              reduce: acc do
            acc -> build_error_details(sub_error_map, [idx, key | path], acc)
          end

        _, acc ->
          acc
      end)
    end
  end

  @derive JSON.Encoder
  defexception errors: []

  @type t :: %__MODULE__{errors: [Entry.t()]}

  @spec new([Entry.t()]) :: t()
  @spec new([Entry.t()], keyword()) :: t()
  def new(entries, opts \\ []) when is_list(entries) do
    entries =
      case Keyword.get(opts, :prefix) || [] do
        [] ->
          entries

        prefix ->
          Enum.map(entries, fn %Entry{path: path} = entry ->
            %{entry | path: Entry.normalize_path(prefix) ++ path}
          end)
      end

    %__MODULE__{errors: entries}
  end

  @impl true
  def message(%__MODULE__{errors: errors}) do
    errors
    |> Enum.map(&JSON.encode!/1)
    |> Enum.join("\n")
  end
end
