defmodule AtomemoPluginSdk.NameValidator do
  @moduledoc """
  名称验证器，用于验证插件定义、工具、模型等的名称格式。
  """

  import Ecto.Changeset

  @name_pattern ~r/^[a-zA-Z](?:(?![_-]{2,})[a-zA-Z0-9_-]){3,63}[a-zA-Z0-9]$/
  @name_error_message "must start with a letter, end with a letter or number, and cannot contain consecutive underscores or hyphens"

  @doc """
  验证名称字段的格式。

  名称必须：
  - 以字母开头
  - 以字母或数字结尾
  - 总长度为 5-65 个字符
  - 不能包含连续的下划线或连字符（`__` 或 `--`）
  """
  def validate_name(changeset, field \\ :name) do
    validate_format(changeset, field, @name_pattern, message: @name_error_message)
  end
end
