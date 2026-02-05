defmodule AtomemoPluginSdk.SocketRuntime do
  @moduledoc """
  Unified runtime for plugin Hub connection in both debug and release mode.

  Reads configuration from environment:
  - `HUB_WS_URL` - WebSocket URL (required when runtime is used)
  - `HUB_MODE` - `"debug"` | `"release"` (default: `"debug"`)
  - `HUB_DEBUG_API_KEY` - API key for debug mode only
  - `HUB_ORGANIZATION_ID` - Organization ID (required)
  """
  use Slipstream, restart: :temporary

  require Logger

  alias AtomemoPluginSdk.{PluginDefinition, SocketRuntimeConfig, ToolDefinition}

  def start_link(opts \\ []) do
    plugin_module = Keyword.fetch!(opts, :plugin_module)
    slipstream_opts = Keyword.take(opts, [:test_mode?])

    Slipstream.start_link(
      __MODULE__,
      [plugin_module: plugin_module],
      Keyword.merge([name: __MODULE__], slipstream_opts)
    )
  end

  @impl true
  def init(args) do
    plugin_module = Keyword.fetch!(args, :plugin_module)

    with {:ok, config} <- load_config(),
         {:ok, plugin} <- call_definition(plugin_module, config.organization_id) do
      uri = build_uri(config)

      case connect(uri: uri, json_parser: JSON) do
        {:ok, socket} ->
          socket =
            socket
            |> assign(:plugin, plugin)
            |> assign(:mode, config.mode)

          {:ok, socket}

        {:error, reason} ->
          Logger.error("[#{inspect(__MODULE__)}] Failed to connect: #{inspect(reason)}")
          {:stop, reason}
      end
    else
      {:error, {:invalid_config, _} = err} ->
        log_config_errors(elem(err, 1))
        {:stop, err}

      {:error, {:definition_failed, _} = err} ->
        log_definition_error(err)
        {:stop, err}
    end
  end

  @impl true
  def handle_connect(socket) do
    %PluginDefinition{} = plugin = Map.fetch!(socket.assigns, :plugin)
    mode = Map.fetch!(socket.assigns, :mode)
    topic = topic_for(plugin, mode)

    Logger.info("[#{inspect(__MODULE__)}] Connected to server, joining topic '#{topic}'")
    {:ok, join(socket, topic)}
  end

  @impl true
  def handle_join(topic, _join_response, socket) do
    Logger.info("[#{inspect(__MODULE__)}] Joined channel '#{topic}' successfully")

    %PluginDefinition{} = plugin = Map.fetch!(socket.assigns, :plugin)
    mode = Map.fetch!(socket.assigns, :mode)

    socket =
      case mode do
        :debug ->
          {:ok, ref} = push(socket, topic, "register_plugin", plugin)
          assign(socket, :claim_request, ref)

        :release ->
          # In release mode, join success means claim success (Hub validates in join callback)
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_reply(ref, message, socket) do
    cond do
      ref == socket.assigns[:claim_request] ->
        Logger.info("message: #{inspect(message)}")

        case message do
          :ok ->
            Logger.info("[#{inspect(__MODULE__)}] Claim/register successfully")
            {:ok, socket}

          {:ok, _} ->
            Logger.info("[#{inspect(__MODULE__)}] Claim/register successfully")
            {:ok, socket}

          {:error, err} ->
            reason = if is_map(err), do: err["reason"] || inspect(err), else: inspect(err)
            Logger.error("[#{inspect(__MODULE__)}] Failed to claim/register: #{inspect(err)}")
            {:stop, reason, socket}
        end

      true ->
        nil
    end

    {:ok, socket}
  end

  @impl true
  def handle_message(topic, event, message, socket) do
    Logger.info(
      "[#{inspect(__MODULE__)}] Received message on '#{topic}': #{event} - #{inspect(message)}"
    )

    case invoke_tool(socket, message) do
      {:ok, result} ->
        push(socket, topic, "invoke_tool_response", %{
          "request_id" => message["request_id"],
          "data" => result
        })

      {:error, reason} ->
        push(socket, topic, "invoke_tool_error", %{
          "request_id" => message["request_id"],
          "error" => reason
        })
    end

    {:ok, socket}
  end

  defp call_definition(plugin_module, organization_id) do
    case plugin_module.definition(organization_id) do
      {:ok, plugin} -> {:ok, plugin}
      {:error, reason} -> {:error, {:definition_failed, reason}}
    end
  rescue
    e -> {:error, {:definition_failed, {:exception, e}}}
  end

  defp log_definition_error({:definition_failed, %Ecto.Changeset{} = changeset}) do
    errors =
      PluginDefinition.traverse_errors(changeset)
      |> Enum.map(fn err -> "  * path: #{inspect(err.path)}, message: #{err.message}" end)
      |> Enum.join("\n")

    Logger.error("[#{inspect(__MODULE__)}] Plugin definition validation failed:\n#{errors}")
  end

  defp log_definition_error({:definition_failed, reason}) do
    Logger.error("[#{inspect(__MODULE__)}] Plugin definition failed: #{inspect(reason)}")
  end

  defp load_config do
    case SocketRuntimeConfig.load_from_env() do
      {:ok, config} -> {:ok, config}
      {:error, changeset} -> {:error, {:invalid_config, changeset}}
    end
  end

  defp log_config_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
      |> Enum.flat_map(fn {field, msgs} -> Enum.map(msgs, &"  #{field}: #{&1}") end)
      |> Enum.join("\n")

    Logger.error("[#{inspect(__MODULE__)}] Invalid runtime config:\n#{errors}")
  end

  defp build_uri(%SocketRuntimeConfig{mode: :debug, ws_url: ws_url, debug_api_key: api_key}) do
    base = URI.new!(ws_url) |> URI.merge("/debug_socket/websocket")

    if is_binary(api_key) and api_key != "" do
      query = URI.encode_query(%{"api_key" => api_key})
      URI.merge(base, "?" <> query)
    else
      base
    end
  end

  defp build_uri(%SocketRuntimeConfig{mode: :release, ws_url: ws_url}) do
    URI.new!(ws_url) |> URI.merge("/release_socket/websocket")
  end

  defp topic_for(%PluginDefinition{} = plugin, :debug) do
    "debug_plugin:#{plugin.name}"
  end

  defp topic_for(%PluginDefinition{} = plugin, :release) do
    # Convention: same as Hub's version_slug for release
    "release_plugin:#{plugin.organization_id}__#{plugin.name}__release__#{plugin.version}"
  end

  defp invoke_tool(socket, message) do
    tool_name = Map.fetch!(message, "tool_name")
    %PluginDefinition{} = plugin = Map.fetch!(socket.assigns, :plugin)
    parameters = message["parameters"] || %{}

    with {:ok, tool} <- find_tool(plugin.tools, tool_name),
         {:ok, result} <- call_tool_invoke(tool, parameters) do
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error(
          "[#{inspect(__MODULE__)}] Failed to invoke tool '#{tool_name}': #{inspect(reason)}"
        )

        {:error, to_string(reason)}
    end
  end

  defp find_tool(tools, tool_name) when is_binary(tool_name) do
    case Enum.find(tools, fn tool -> tool.name == tool_name end) do
      nil -> {:error, "Tool '#{tool_name}' not found"}
      tool -> {:ok, tool}
    end
  end

  defp call_tool_invoke(%ToolDefinition{} = tool, parameters) do
    try do
      if is_function(tool.invoke, 1) do
        case tool.invoke.(parameters) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
          other -> {:error, "Unexpected return value: #{inspect(other)}"}
        end
      else
        {:error, "Tool '#{tool.name}' has no invoke function"}
      end
    rescue
      err ->
        {:error, "Exception during tool '#{tool.name}' invocation: #{Exception.message(err)}"}
    catch
      kind, reason ->
        {:error, "Caught #{kind} in tool '#{tool.name}': #{inspect(reason)}"}
    end
  end

  @impl true
  def handle_disconnect(reason, socket) do
    Logger.warning(
      "[#{inspect(__MODULE__)}] Disconnected from server, reason: #{inspect(reason)}"
    )

    reconnect(socket)
  end
end
