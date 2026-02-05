defmodule AtomemoPluginSdk.JSONValue do
  @moduledoc """
  Ecto.Type 实现，用于存储任意的 JSON 值。

  支持所有 JSON 值类型：
  - 字符串 (string)
  - 数字 (integer/float)
  - 布尔值 (boolean)
  - null
  - 对象 (map)
  - 数组 (list)

  ## Examples

      iex> JSONValue.cast("hello")
      {:ok, "hello"}

      iex> JSONValue.cast(123)
      {:ok, 123}

      iex> JSONValue.cast(%{"key" => "value"})
      {:ok, %{"key" => "value"}}

      iex> JSONValue.cast([1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> JSONValue.cast(nil)
      {:ok, nil}
  """

  use Ecto.Type

  @type t() :: String.t() | number() | boolean() | map() | list() | nil

  def type, do: :map

  def cast(value) do
    case validate_json_value(value) do
      :ok -> {:ok, value}
      {:error, reason} -> {:error, [message: reason]}
    end
  end

  def load(value)
      when is_binary(value)
      when is_integer(value)
      when is_float(value)
      when is_boolean(value)
      when is_map(value)
      when is_list(value) do
    {:ok, value}
  end

  def load(nil), do: {:ok, nil}
  def load(_), do: :error

  def dump(value)
      when is_binary(value)
      when is_integer(value)
      when is_float(value)
      when is_boolean(value)
      when is_map(value)
      when is_list(value) do
    {:ok, value}
  end

  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error

  defp validate_json_value(nil), do: :ok

  defp validate_json_value(value)
       when is_binary(value)
       when is_integer(value)
       when is_float(value)
       when is_boolean(value) do
    :ok
  end

  defp validate_json_value(map) when is_map(map) do
    Enum.reduce_while(map, :ok, fn {key, value}, _acc ->
      cond do
        not is_binary(key) ->
          {:halt, {:error, "map keys must be strings"}}

        true ->
          case validate_json_value(value) do
            :ok -> {:cont, :ok}
            {:error, _} = error -> {:halt, error}
          end
      end
    end)
  end

  defp validate_json_value(list) when is_list(list) do
    Enum.reduce_while(list, :ok, fn value, _acc ->
      case validate_json_value(value) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_json_value(_), do: {:error, "invalid JSON value"}
end
