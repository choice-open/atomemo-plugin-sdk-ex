defmodule AtomemoPluginSdk.ParameterValidator.Error do
  @moduledoc false

  defexception [:issues, :message, :source]

  @type issue :: %{
          required(:path) => list(),
          required(:message) => String.t()
        }

  @type source :: :default_definition | :runtime_input

  @type t :: %__MODULE__{issues: [issue()], message: binary() | nil, source: source()}

  @spec new([issue()], keyword()) :: t()
  def new(issues, opts \\ [])

  def new(issues, opts) when is_list(issues) do
    %__MODULE__{
      issues: issues,
      source: Keyword.fetch!(opts, :source)
    }
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
end
