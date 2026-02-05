defmodule AtomemoPluginSdk.PluginDefinition do
  @moduledoc """
  插件定义结构体，用于描述插件的基本信息和分类。
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AtomemoPluginSdk.{
    I18nEntry,
    CredentialDefinition,
    ToolDefinition,
    ModelDefinition,
    NameValidator,
    VersionValidator
  }

  @derive JSON.Encoder
  @primary_key false
  embedded_schema do
    field :organization_id, :string
    field :lang, Ecto.Enum, values: [:typescript, :elixir]
    field :name, :string
    field :display_name, I18nEntry
    field :description, I18nEntry
    field :icon, :string
    field :author, :string
    field :email, :string
    field :repo, :string
    field :version, :string
    field :locales, {:array, :string}, default: ["en_US"]

    embeds_many :credentials, CredentialDefinition, on_replace: :delete
    embeds_many :tools, ToolDefinition, on_replace: :delete
    embeds_many :models, ModelDefinition, on_replace: :delete
  end

  @type t() :: %__MODULE__{
          organization_id: String.t(),
          lang: :typescript | :elixir | nil,
          name: String.t(),
          display_name: I18nEntry.t() | nil,
          description: I18nEntry.t() | nil,
          icon: String.t() | nil,
          author: String.t() | nil,
          email: String.t() | nil,
          repo: String.t() | nil,
          version: String.t() | nil,
          locales: [String.t()]
        }

  def changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [
      :organization_id,
      :lang,
      :name,
      :display_name,
      :description,
      :icon,
      :author,
      :email,
      :repo,
      :version,
      :locales
    ])
    |> validate_required([
      :organization_id,
      :lang,
      :name,
      :display_name,
      :description,
      :icon,
      :author,
      :email,
      :version
    ])
    |> NameValidator.validate_name()
    |> VersionValidator.validate_version()
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> cast_embed(:credentials)
    |> cast_embed(:tools)
    |> cast_embed(:models)
  end

  @doc """
  创建新的插件定义。

  ## Examples

      iex> PluginDefinition.new(%{
      ...>   organization_id: "my_org",
      ...>   name: "my_plugin",
      ...>   display_name: %{"en_US" => "My Plugin"},
      ...>   description: %{"en_US" => "My awesome plugin"},
      ...>   icon: "🔌",
      ...>   author: "John Doe",
      ...>   email: "john@example.com",
      ...>   repo: "https://github.com/example/my_plugin",
      ...>   version: "1.0.0"
      ...> })
      {:ok, %PluginDefinition{}}

      iex> PluginDefinition.new(%{name: "my_plugin"})
      {:error, %Ecto.Changeset{}}

  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  遍历并格式化 changeset 错误，支持 PolymorphicEmbed 的错误。

  ## Examples

      iex> {:error, changeset} = PluginDefinition.new(%{name: "test"})
      iex> PluginDefinition.traverse_errors(changeset)
      [
        {path: [:credentials, 0, :parameters, 0, :name], message: "can't be blank"},
        {path: [:tools, 0, :display_name], message: "can't be blank"},
        {path: [:models, 0, :parameters, 0, :name], message: "can't be blank"}
      ]
  """
  def traverse_errors(changeset) do
    PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> build_error_details([], [])
  end

  defp build_error_details(error_map, path, acc) do
    Enum.reduce(error_map, acc, fn
      # 属性，有多个错误
      {key, [msg | _] = msgs}, acc when is_binary(msg) ->
        for msg <- msgs, reduce: acc do
          acc ->
            item = %{
              path: Enum.reverse([key | path]),
              message: msg
            }

            [item | acc]
        end

      # 1:1 关联
      {key, sub_error_map}, acc when is_map(sub_error_map) ->
        build_error_details(sub_error_map, [key | path], acc)

      # 1:N 关联
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
