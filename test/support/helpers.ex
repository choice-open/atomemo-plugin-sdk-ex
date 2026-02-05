defmodule AtomemoPluginSdk.TestHelpers do
  @moduledoc """
  测试辅助函数
  """

  @doc """
  从 changeset 中提取错误信息，返回一个 map，其中 key 是字段名，value 是错误消息列表。
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
  end
end
