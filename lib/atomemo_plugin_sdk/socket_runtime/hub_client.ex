defmodule AtomemoPluginSdk.SocketRuntime.HubClient do
  @moduledoc """
  Unified runtime for plugin Hub connection in both debug and release mode.

  Reads configuration from environment:
  - `HUB_WS_URL` - WebSocket URL (required when runtime is used)
  - `HUB_MODE` - `"debug"` | `"release"` (default: `"debug"`)
  - `HUB_DEBUG_API_KEY` - API key for debug mode only
  """
  use Slipstream, restart: :temporary

  require Logger

  alias AtomemoPluginSdk.{Context, CredentialDefinition, PluginDefinition, SocketRuntimeConfig}
  alias AtomemoPluginSdk.{SdkError, TransientError}
  alias AtomemoPluginSdk.SocketRuntime.{CredentialInvoker, ToolInvoker}

  def start_link(opts \\ []) do
    init_arg = Keyword.take(opts, [:plugin_module, :task_supervisor, :name])
    slipstream_opts = Keyword.take(opts, [:name, :test_mode?])
    Slipstream.start_link(__MODULE__, init_arg, slipstream_opts)
  end

  @impl true
  def init(args) do
    plugin_module = Keyword.fetch!(args, :plugin_module)
    client_name = Keyword.get(args, :name)
    task_supervisor = Keyword.fetch!(args, :task_supervisor)

    with {:ok, config} <- load_config(),
         {:ok, plugin} <- call_definition(plugin_module) do
      uri = build_uri(config)

      case connect(uri: uri, json_parser: JSON) do
        {:ok, socket} ->
          socket =
            socket
            |> assign(:name, client_name)
            |> assign(:task_supervisor, task_supervisor)
            |> assign(:plugin, plugin)
            |> assign(:mode, config.mode)
            |> assign(:pending_hub_calls, %{})

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
          assign(socket, :register_plugin_ref, ref)

        :release ->
          # In release mode, join success means claim success (Hub validates in join callback)
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_reply(ref, message, socket) do
    if ref == socket.assigns[:register_plugin_ref] do
      socket = assign(socket, :register_plugin_ref, nil)

      case message do
        :ok ->
          Logger.info("[#{inspect(__MODULE__)}] Register plugin successfully")
          {:ok, socket}

        {:ok, _} ->
          Logger.info("[#{inspect(__MODULE__)}] Register plugin successfully")
          {:ok, socket}

        {:error, err} ->
          reason = if is_map(err), do: err["reason"] || inspect(err), else: inspect(err)
          Logger.error("[#{inspect(__MODULE__)}] Failed to register plugin: #{inspect(err)}")
          {:stop, reason, socket}
      end
    else
      {:ok, socket}
    end
  end

  defp handle_hub_call_push_response(socket, message, status) do
    request_id = message["request_id"]
    topic = current_topic(socket)

    case Map.pop(socket.assigns.pending_hub_calls, request_id) do
      {nil, _} ->
        Logger.warning(
          "[#{inspect(__MODULE__)}] Received hub_call response for unknown request_id=#{request_id} topic=#{topic}"
        )

        socket

      {{:hub_call, from}, pending} ->
        case status do
          :ok ->
            Logger.info(
              "[#{inspect(__MODULE__)}] Dispatching hub_call response topic=#{topic} request_id=#{request_id}"
            )

            send(from, {:hub_call_response, request_id, message["data"]})

          :error ->
            Logger.info(
              "[#{inspect(__MODULE__)}] Dispatching hub_call error topic=#{topic} request_id=#{request_id}"
            )

            send(from, {:hub_call_error, request_id, message["error"]})
        end

        assign(socket, :pending_hub_calls, pending)
    end
  end

  @impl true
  def handle_message(topic, event, message, socket) do
    Logger.info(
      "[#{inspect(__MODULE__)}] Received message on '#{topic}': #{event} - #{inspect(message)}"
    )

    socket =
      case event do
        "credential_auth_spec" ->
          handle_credential_auth_spec(socket, topic, message)

        "invoke_tool" ->
          handle_invoke_tool(socket, topic, message)

        "hub_call_response" ->
          handle_hub_call_push_response(socket, message, :ok)

        "hub_call_error" ->
          handle_hub_call_push_response(socket, message, :error)

        _ ->
          error = SdkError.new(:invalid_event, "Invalid event: #{event}")

          push(socket, topic, "invoke_tool_error", %{
            "request_id" => message["request_id"],
            "error" => SdkError.to_map(error)
          })

          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({event, topic, request_id, result}, socket)
      when event in [:invoke_tool_response, :credential_auth_spec_response] do
    push(socket, topic, to_string(event), %{
      "request_id" => request_id,
      "data" => result
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({event, topic, request_id, error}, socket)
      when event in [:invoke_tool_error, :credential_auth_spec_error] do
    error_payload =
      case error do
        %SdkError{} = err -> SdkError.to_map(err)
        %TransientError{} = err -> TransientError.to_map(err)
        %{} = map -> map
        other -> other
      end

    push(socket, topic, to_string(event), %{
      "request_id" => request_id,
      "error" => error_payload
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:hub_call, event, request_id, payload, from}, socket) do
    topic = current_topic(socket)

    Logger.info(
      "[#{inspect(__MODULE__)}] Sending hub_call topic=#{topic} event=#{event} request_id=#{request_id} payload=#{inspect(payload)}"
    )

    push(socket, topic, "hub_call:#{event}", %{"request_id" => request_id, "data" => payload})

    pending = Map.put(socket.assigns.pending_hub_calls, request_id, {:hub_call, from})
    {:noreply, assign(socket, :pending_hub_calls, pending)}
  end

  @impl true
  def handle_info({:hub_call_cancel, request_id}, socket) do
    topic = current_topic(socket)

    Logger.info(
      "[#{inspect(__MODULE__)}] Cancelling hub_call topic=#{topic} request_id=#{request_id}"
    )

    pending = Map.delete(socket.assigns.pending_hub_calls, request_id)
    {:noreply, assign(socket, :pending_hub_calls, pending)}
  end

  defp handle_invoke_tool(socket, topic, message) do
    with {:ok, request_id} <- extract_request_id(message),
         {:ok, tool_name} <- extract_tool_name(message),
         {:ok, tool} <- find_tool_by_name(socket, tool_name) do
      parameters = message["parameters"] || %{}
      credentials = message["credentials"] || %{}
      raw_context = message["context"] || %{}
      task_supervisor = socket.assigns.task_supervisor
      hub_client = get_hub_client(socket)

      Task.Supervisor.start_child(task_supervisor, fn ->
        context = %Context{
          __hub_client__: hub_client,
          organization_id: raw_context["organization_id"]
        }

        args = %{
          request_id: request_id,
          parameters: parameters,
          credentials: credentials,
          context: context
        }

        case ToolInvoker.invoke(tool, args) do
          {:ok, result} ->
            send(hub_client, {:invoke_tool_response, topic, request_id, result})

          {:error, error} ->
            send(hub_client, {:invoke_tool_error, topic, request_id, error})
        end
      end)

      socket
    else
      {:error, %SdkError{} = err} ->
        push(socket, topic, "invoke_tool_error", %{
          "request_id" => message["request_id"],
          "error" => SdkError.to_map(err)
        })

        socket
    end
  end

  defp get_hub_client(socket) do
    socket.assigns[:name] || self()
  end

  defp extract_request_id(message) do
    case message["request_id"] do
      nil -> {:error, SdkError.new(:invalid_request_id, "request_id is required")}
      "" -> {:error, SdkError.new(:invalid_request_id, "request_id is required")}
      request_id when is_binary(request_id) -> {:ok, request_id}
      _ -> {:error, SdkError.new(:invalid_request_id, "request_id must be a string")}
    end
  end

  defp extract_tool_name(message) do
    case message["tool_name"] do
      nil -> {:error, SdkError.new(:invalid_tool_name, "tool_name is required")}
      "" -> {:error, SdkError.new(:invalid_tool_name, "tool_name is required")}
      tool_name when is_binary(tool_name) -> {:ok, tool_name}
      _ -> {:error, SdkError.new(:invalid_tool_name, "tool_name must be a string")}
    end
  end

  defp extract_credential_name(message) do
    case message["credential_name"] do
      nil ->
        {:error, SdkError.new(:invalid_credential_name, "credential_name is required")}

      "" ->
        {:error, SdkError.new(:invalid_credential_name, "credential_name is required")}

      credential_name when is_binary(credential_name) ->
        {:ok, credential_name}

      _ ->
        {:error, SdkError.new(:invalid_credential_name, "credential_name must be a string")}
    end
  end

  defp find_tool_by_name(socket, tool_name) do
    plugin = socket.assigns.plugin

    case find_tool(plugin.tools, tool_name) do
      {:ok, tool} ->
        {:ok, tool}

      {:error, _} ->
        {:error, SdkError.new(:tool_not_found, "Tool '#{tool_name}' not found")}
    end
  end

  defp find_credential_for_auth(socket, credential_name) do
    plugin = socket.assigns.plugin

    case find_credential_definition(plugin.credentials, credential_name) do
      %CredentialDefinition{} = cred_def ->
        {:ok, cred_def}

      nil ->
        {:error, SdkError.new(:credential_not_found, "Credential '#{credential_name}' not found")}
    end
  end

  defp handle_credential_auth_spec(socket, topic, message) do
    with {:ok, request_id} <- extract_request_id(message),
         {:ok, credential_name} <- extract_credential_name(message),
         {:ok, cred_def} <- find_credential_for_auth(socket, credential_name) do
      task_supervisor = socket.assigns.task_supervisor
      hub_client = get_hub_client(socket)

      Task.Supervisor.start_child(task_supervisor, fn ->
        case CredentialInvoker.authenticate(cred_def, message) do
          {:ok, spec} ->
            send(hub_client, {:credential_auth_spec_response, topic, request_id, spec})

          {:error, error} ->
            send(hub_client, {:credential_auth_spec_error, topic, request_id, error})
        end
      end)

      socket
    else
      {:error, %SdkError{} = err} ->
        push(socket, topic, "credential_auth_spec_error", %{
          "request_id" => message["request_id"],
          "error" => SdkError.to_map(err)
        })

        socket
    end
  end

  defp find_credential_definition(credentials, credential_name)
       when is_list(credentials) and is_binary(credential_name) do
    Enum.find(credentials, fn cred -> cred.name == credential_name end)
  end

  defp call_definition(plugin_module) do
    case plugin_module.definition() do
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
    "release_plugin:#{plugin.name}__release__#{plugin.version}"
  end

  defp current_topic(socket) do
    plugin = socket.assigns.plugin
    mode = socket.assigns.mode
    topic_for(plugin, mode)
  end

  defp find_tool(tools, tool_name) when is_binary(tool_name) do
    case Enum.find(tools, fn tool -> tool.name == tool_name end) do
      nil -> {:error, "Tool '#{tool_name}' not found"}
      tool -> {:ok, tool}
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
