defmodule AtomemoPluginSdk.ParameterDefinition.Base do
  @moduledoc """
  ParameterDefinition 的公共基础字段，对应 TS 中的 `NodePropertyBase`。
  """

  import Ecto.Changeset

  alias AtomemoPluginSdk.{I18nEntry, JSONValue}

  defmacro base_schema do
    quote do
      field :decoder, Ecto.Enum, values: [:json]
      field :name, :string
      field :display_name, I18nEntry
      field :required, :boolean, default: false
      field :display, :map
      field :constant, JSONValue
      field :default, JSONValue
      field :enum, {:array, JSONValue}
      field :depends_on, {:array, :string}
      field :ai, :map
      field :ui, :map
    end
  end

  defmacro __using__(opts) do
    allow_default = Keyword.get(opts, :allow_default, true)

    case is_boolean(allow_default) do
      true ->
        :ok

      false ->
        raise ArgumentError,
              "invalid :allow_default option for use #{inspect(__MODULE__)}: " <>
                "expected boolean, got #{inspect(allow_default)}"
    end

    quote do
      @after_compile {unquote(__MODULE__), :ensure_protocol_implementation!}

      import unquote(__MODULE__)

      alias AtomemoPluginSdk.ParameterCodec, as: PC

      def __allow_default__, do: unquote(allow_default)

      def validate_default_if_needed(changeset) do
        cond do
          not changeset.valid? ->
            changeset

          changeset |> get_field(:default) |> is_nil() ->
            changeset

          true ->
            case changeset |> apply_changes() |> PC.validate_default() do
              :ok ->
                changeset

              {:error, %AtomemoPluginSdk.ParameterError{} = error} ->
                add_error(changeset, :default, AtomemoPluginSdk.ParameterError.message(error))
            end
        end
      end
    end
  end

  def ensure_protocol_implementation!(env, _bytecode) do
    env.module
    |> struct()
    |> AtomemoPluginSdk.ParameterCodec.Codecable.impl_for!()
  end

  def cast_and_validate_base_fields(changeset, attrs) do
    changeset
    |> cast(attrs, [
      :decoder,
      :type,
      :name,
      :display_name,
      :required,
      :display,
      :constant,
      :default,
      :enum,
      :depends_on,
      :ai,
      :ui
    ])
    |> validate_required([:type])
  end
end
