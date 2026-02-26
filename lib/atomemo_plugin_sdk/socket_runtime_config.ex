defmodule AtomemoPluginSdk.SocketRuntimeConfig do
  @moduledoc """
  Validated configuration for SocketRuntime loaded from environment variables.

  Env vars:
  - `HUB_WS_URL` - WebSocket URL (required), must be `ws://` or `wss://`
  - `HUB_MODE` - `"debug"` | `"release"` (default: `"debug"`)
  - `HUB_DEBUG_API_KEY` - Required when mode is debug, non-empty string
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :ws_url, :string
    field :mode, Ecto.Enum, values: [:debug, :release]
    field :debug_api_key, :string
  end

  @type t() :: %__MODULE__{
          ws_url: String.t(),
          mode: :debug | :release,
          debug_api_key: String.t() | nil
        }

  @ws_schemes ~w(ws wss)

  @doc """
  Load and validate config from environment. Returns `{:ok, config}` or `{:error, changeset}`.
  """
  def load_from_env do
    attrs = %{
      ws_url: System.get_env("HUB_WS_URL"),
      mode: System.get_env("HUB_MODE", "debug"),
      debug_api_key: System.get_env("HUB_DEBUG_API_KEY")
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:validate)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:ws_url, :mode, :debug_api_key])
    |> validate_required([:ws_url, :mode])
    |> validate_ws_url()
    |> apply_mode_debug_api_key()
  end

  defp validate_ws_url(changeset) do
    validate_change(changeset, :ws_url, fn :ws_url, value ->
      if value != nil and value != "" and not valid_ws_uri?(value) do
        [ws_url: "HUB_WS_URL must be a valid WebSocket URL (ws:// or wss://)"]
      else
        []
      end
    end)
  end

  defp valid_ws_uri?(str) do
    case URI.parse(str) do
      %URI{scheme: scheme, host: host}
      when scheme in @ws_schemes and is_binary(host) and host != "" ->
        true

      _ ->
        false
    end
  end

  defp apply_mode_debug_api_key(changeset) do
    if get_field(changeset, :mode) == :debug do
      validate_required(changeset, [:debug_api_key])
    else
      delete_change(changeset, :debug_api_key)
    end
  end
end
