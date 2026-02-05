defmodule AtomemoPluginSdk.VersionValidator do
  @moduledoc """
  版本验证器，用于验证插件版本是否符合 SemVer 2.0.0 规范。

  SemVer 格式：MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
  - MAJOR, MINOR, PATCH: 非负整数
  - PRERELEASE: 可选，由点分隔的标识符，每个标识符只能包含字母数字和连字符
  - BUILD: 可选，由点分隔的标识符，每个标识符只能包含字母数字和连字符
  - 不允许下划线（避免与 version_slug 分隔符冲突）
  """

  import Ecto.Changeset

  # SemVer 2.0.0 格式：
  # - 必需部分：MAJOR.MINOR.PATCH（数字.数字.数字）
  # - 可选预发布：-标识符（标识符由字母数字和连字符组成，可用点分隔多个）
  # - 可选构建：+标识符（标识符由字母数字和连字符组成，可用点分隔多个）
  # - 明确禁止下划线（避免与 version_slug 的 __ 分隔符冲突）
  @semver_pattern ~r/^\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$/
  @version_error_message "must follow SemVer 2.0.0 format (MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]) and cannot contain underscores"

  @doc """
  验证版本字段是否符合 SemVer 2.0.0 规范。

  版本必须：
  - 格式为 MAJOR.MINOR.PATCH（如 "1.0.0"）
  - 可选的预发布版本（如 "1.0.0-alpha.1"）
  - 可选的构建元数据（如 "1.0.0+build.1"）
  - 不能包含下划线（避免与 version_slug 分隔符冲突）

  ## Examples

      iex> VersionValidator.validate_version(changeset, :version)
      # 有效版本：
      # - "1.0.0"
      # - "1.0.0-alpha"
      # - "1.0.0-alpha.1"
      # - "1.0.0+build.1"
      # - "1.0.0-alpha+build.1"
      # 无效版本：
      # - "1.0" (缺少 PATCH)
      # - "1.0.0_alpha" (包含下划线)
      # - "1__0__0" (包含双下划线)
  """
  def validate_version(changeset, field \\ :version) do
    validate_format(changeset, field, @semver_pattern, message: @version_error_message)
  end
end
