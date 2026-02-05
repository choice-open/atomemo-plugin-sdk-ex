defmodule AtomemoPluginSdk.I18nEntry do
  @moduledoc """
  Ecto.Type 实现，用于存储国际化条目。

  该类型是一个 map，key 和 value 都是 string。
  必须包含 "en_US" key，其他 key 可选。
  其他 key 格式：`<语言代码>_<国家或脚本代码>`，语言代码 2 位，国家/脚本代码首字母大写。

  ## Examples

      iex> I18nEntry.cast(%{"en_US" => "Hello", "zh_Hans" => "你好"})
      {:ok, %{"en_US" => "Hello", "zh_Hans" => "你好"}}

      iex> I18nEntry.cast(%{"zh_Hans" => "你好"})
      {:error, [message: "must contain \"en_US\" key"]}
  """

  use Ecto.Type

  @type t() :: %{String.t() => String.t()}

  def type, do: :map

  def cast(value) when is_map(value) do
    case validate_i18n_entry(value) do
      :ok -> {:ok, value}
      {:error, reason} -> {:error, [message: reason]}
    end
  end

  def cast(_), do: :error

  def load(value) when is_map(value) do
    {:ok, value}
  end

  def load(_), do: :error

  def dump(value) when is_map(value) do
    {:ok, value}
  end

  def dump(_), do: :error

  defp validate_i18n_entry(map) do
    with :ok <- validate_map_structure(map),
         :ok <- validate_required_en_us(map),
         :ok <- validate_keys_format(map) do
      :ok
    end
  end

  defp validate_map_structure(map) do
    if Enum.all?(map, fn {k, v} -> is_binary(k) and is_binary(v) end) do
      :ok
    else
      {:error, "all keys and values must be strings"}
    end
  end

  defp validate_required_en_us(map) do
    if Map.has_key?(map, "en_US") do
      :ok
    else
      {:error, "must contain \"en_US\" key"}
    end
  end

  defp validate_keys_format(map) do
    invalid_keys =
      map
      |> Map.keys()
      |> Enum.reject(&valid_locale_key?/1)

    if Enum.empty?(invalid_keys) do
      :ok
    else
      {:error, "invalid locale key: #{inspect(invalid_keys)}"}
    end
  end

  defp valid_locale_key?("en_US"), do: true

  defp valid_locale_key?(key) when is_binary(key) do
    case String.split(key, "_", parts: 2) do
      [lang_code, country_code] ->
        String.match?(lang_code, ~r/^[a-z]{2}$/) and
          String.match?(country_code, ~r/^[A-Z]/)

      _ ->
        false
    end
  end

  defp valid_locale_key?(_), do: false
end
