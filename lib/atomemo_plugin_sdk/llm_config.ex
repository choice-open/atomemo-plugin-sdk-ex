defmodule AtomemoPluginSdk.LLMConfig do
  use Ecto.Schema
  import Ecto.Changeset
  alias AtomemoPluginSdk.ParameterError, as: Error

  @type t() :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :plugin_slug, :string
    field :version_slug, :string
    field :model, :string
    field :credential_instance_id, :string

    embeds_one :model_params, __MODULE__.ModelParams, on_replace: :delete
  end

  @doc false
  def changeset(llm_config, attrs \\ %{}) do
    llm_config
    |> cast(attrs, [:plugin_slug, :version_slug, :model, :credential_instance_id])
    |> validate_required([:plugin_slug, :version_slug, :model])
    |> cast_embed(:model_params, required: true)
  end

  def hydrate_changeset(llm_config \\ %__MODULE__{}, attrs) do
    changeset(llm_config, attrs)
  end

  @spec new(%{optional(String.t()) => any()} | %{optional(atom()) => any}) ::
          {:ok, t()} | {:error, String.t()}
  def new(attrs) do
    case %__MODULE__{} |> changeset(attrs) |> apply_action(:insert) do
      {:ok, file_ref} -> {:ok, file_ref}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec new!(%{optional(String.t()) => any()} | %{optional(atom()) => any}) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, changeset} -> raise Error.new(changeset, source: :runtime)
    end
  end

  defmodule ModelParams do
    use Ecto.Schema

    import Ecto.Changeset

    @type t() :: %__MODULE__{}

    @primary_key false
    @derive JSON.Encoder
    @derive Jason.Encoder
    embedded_schema do
      field :structured_outputs, :boolean, default: false
      field :json_schema, :map
      field :verbosity, :string
      field :temperature, :float
      field :frequency_penalty, :float
    end

    @doc false
    def changeset(model_params, attrs \\ %{}) do
      model_params
      |> cast(attrs, [
        :structured_outputs,
        :json_schema,
        :verbosity,
        :temperature,
        :frequency_penalty
      ])
    end

    @spec new(%{optional(String.t()) => any()} | %{optional(atom()) => any}) ::
            {:ok, t()} | {:error, Ecto.Changeset.t()}
    def new(attrs) do
      %__MODULE__{}
      |> changeset(attrs)
      |> apply_action(:insert)
    end

    @spec new!(%{optional(String.t()) => any()} | %{optional(atom()) => any}) :: t()
    def new!(attrs) do
      %__MODULE__{}
      |> changeset(attrs)
      |> apply_action!(:insert)
    end
  end
end

defimpl JSON.Encoder, for: AtomemoPluginSdk.LLMConfig do
  def encode(%@for{} = llm_config, _encoder) do
    llm_config
    |> Map.from_struct()
    |> Map.put_new(:__type__, "llm_config")
    |> JSON.encode_to_iodata!()
  end
end
