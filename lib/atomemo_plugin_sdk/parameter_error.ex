defmodule AtomemoPluginSdk.ParameterError do
  @moduledoc false

  defexception [:issues, :message, :source]

  @type issue :: %{
          required(:path) => list(),
          required(:message) => String.t()
        }

  @type source :: :input | :plugin | :runtime

  @type t :: %__MODULE__{issues: [issue()], message: binary() | nil, source: source()}

  @spec new([issue()], keyword()) :: t()
  def new(issues, opts \\ [])

  def new(issues, opts) when is_list(issues) do
    %__MODULE__{
      issues: issues,
      source: Keyword.fetch!(opts, :source)
    }
  end

  def new(%Ecto.Changeset{} = changeset, opts) do
    changeset
    |> issues_from_changeset()
    |> new(opts)
  end

  def new(issue, opts) when is_map(issue) do
    new([issue], opts)
  end

  def new(message, opts) when is_binary(message) do
    %__MODULE__{message: message, issues: [], source: Keyword.fetch!(opts, :source)}
  end

  @impl true
  def message(%__MODULE__{message: message}) when is_binary(message) do
    message
  end

  def message(%__MODULE__{issues: issues}) do
    issues
    |> Enum.map(fn issue ->
      "#{format_path(issue.path)}: #{issue.message}"
    end)
    |> Enum.join("\n")
  end

  defp format_path(path, acc \\ "")

  defp format_path(atom, acc) when is_atom(atom) do
    atom |> Atom.to_string() |> format_path(acc)
  end

  defp format_path(binary, "") when is_binary(binary) do
    binary
  end

  defp format_path(binary, acc) when is_binary(binary) do
    acc <> "." <> binary
  end

  defp format_path(index, acc) when is_integer(index) do
    acc <> "[#{index}]"
  end

  defp format_path([], acc), do: acc

  defp format_path([segment | rest], acc) do
    format_path(rest, format_path(segment, acc))
  end

  @doc """
  遍历并格式化 changeset 错误，支持 PolymorphicEmbed 的错误。

  ## Returns

      [
        {path: [:credentials, 0, :parameters, 0, :name], message: "can't be blank"},
        {path: [:tools, 0, :display_name], message: "can't be blank"},
        {path: [:models, 0, :parameters, 0, :name], message: "can't be blank"}
      ]
  """
  def issues_from_changeset(changeset) do
    PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
    |> build_error_details()
  end

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
