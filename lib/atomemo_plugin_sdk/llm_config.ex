defmodule AtomemoPluginSdk.LLMConfig do
  use Ecto.Schema

  @type t() :: %__MODULE__{
          version_slug: String.t(),
          model: String.t(),
          credential_instance_id: String.t(),
          model_params: __MODULE__.ModelParams.t()
        }

  @field_specs [
    {:version_slug, :string, []},
    {:model, :string, []},
    {:credential_instance_id, :string, []}
  ]

  @fields Enum.map(@field_specs, &elem(&1, 0))

  @required_fields [
    :version_slug,
    :model
  ]

  @primary_key false
  @derive JSON.Encoder
  @derive Jason.Encoder
  embedded_schema do
    for {name, type, opts} <- @field_specs do
      field(name, type, opts)
    end

    embeds_one :model_params, __MODULE__.ModelParams, on_replace: :delete
  end

  @doc false
  def changeset(llm_config, attrs \\ %{}) do
    llm_config
    |> Ecto.Changeset.cast(attrs, @fields)
    |> Ecto.Changeset.validate_required(@required_fields)
    |> Ecto.Changeset.cast_embed(:model_params)
    |> Ecto.Changeset.validate_required([:model_params])
  end

  @spec new(%{optional(String.t()) => any()} | %{optional(atom()) => any}) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Ecto.Changeset.apply_action(:insert)
  end

  @spec new!(%{optional(String.t()) => any()} | %{optional(atom()) => any}) :: t()
  def new!(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Ecto.Changeset.apply_action!(:insert)
  end

  defmodule ModelParams do
    use Ecto.Schema

    @type t() :: %__MODULE__{
            structured_outputs: boolean(),
            json_schema: nil | map(),
            verbosity: nil | String.t(),
            temperature: nil | float(),
            frequency_penalty: nil | float()
          }

    @field_specs [
      # {:stream, :boolean, [default: false]},
      {:structured_outputs, :boolean, [default: false]},
      {:json_schema, :map, []},
      {:verbosity, :string, []},
      {:temperature, :float, []},
      {:frequency_penalty, :float, []}
    ]

    @fields Enum.map(@field_specs, &elem(&1, 0))

    @primary_key false
    @derive JSON.Encoder
    @derive Jason.Encoder
    embedded_schema do
      for {name, type, opts} <- @field_specs do
        field(name, type, opts)
      end
    end

    @doc false
    def changeset(model_params, attrs \\ %{}) do
      model_params
      |> Ecto.Changeset.cast(attrs, @fields)
    end

    @spec new(%{optional(String.t()) => any()} | %{optional(atom()) => any}) ::
            {:ok, t()} | {:error, Ecto.Changeset.t()}
    def new(attrs) do
      %__MODULE__{}
      |> changeset(attrs)
      |> Ecto.Changeset.apply_action(:insert)
    end

    @spec new!(%{optional(String.t()) => any()} | %{optional(atom()) => any}) :: t()
    def new!(attrs) do
      %__MODULE__{}
      |> changeset(attrs)
      |> Ecto.Changeset.apply_action!(:insert)
    end
  end
end
