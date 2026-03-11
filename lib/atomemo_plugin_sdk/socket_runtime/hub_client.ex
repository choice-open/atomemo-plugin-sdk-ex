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

  alias AtomemoPluginSdk.{
    Context,
    CredentialDefinition,
    PluginDefinition,
    SocketRuntimeConfig,
    ToolDefinition
  }

  alias AtomemoPluginSdk.{SdkError, TransientError}
  alias AtomemoPluginSdk.SocketRuntime.CallbackRunner

  @max_tool_timeout_ms 30 * 60 * 1_000
  @credential_auth_timeout_ms 5_000
  @oauth2_timeout_ms 60_000

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

        "oauth2_build_authorize_url" ->
          handle_oauth2_build_authorize_url(socket, topic, message)

        "oauth2_get_token" ->
          handle_oauth2_get_token(socket, topic, message)

        "oauth2_refresh_token" ->
          handle_oauth2_refresh_token(socket, topic, message)

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
      when event in [
             :invoke_tool_response,
             :credential_auth_spec_response,
             :oauth2_build_authorize_url_response,
             :oauth2_get_token_response,
             :oauth2_refresh_token_response
           ] do
    push(socket, topic, to_string(event), %{
      "request_id" => request_id,
      "data" => result
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({event, topic, request_id, error}, socket)
      when event in [
             :invoke_tool_error,
             :credential_auth_spec_error,
             :oauth2_build_authorize_url_error,
             :oauth2_get_token_error,
             :oauth2_refresh_token_error
           ] do
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
      hub_client = get_hub_client(socket)
      parameters = message["parameters"] || %{}
      credentials = message["credentials"] || %{}
      raw_context = message["context"] || %{}
      context = build_context(raw_context, hub_client, request_id)

      args = %{
        parameters: parameters,
        credentials: credentials,
        context: context
      }

      timeout_ms = min(tool.timeout || @max_tool_timeout_ms, @max_tool_timeout_ms)

      CallbackRunner.dispatch(
        tool.invoke,
        args,
        task_supervisor: socket.assigns.task_supervisor,
        context: context,
        ok_event: :invoke_tool_response,
        error_event: :invoke_tool_error,
        topic: topic,
        run_opts: [
          label: "tool '#{tool.name}' invocation",
          timeout_ms: timeout_ms,
          invalid_callback_error:
            SdkError.new(
              :invalid_tool_invoke,
              "Tool '#{tool.name}' must have invoke function with 1 argument"
            )
        ]
      )

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

  defp build_context(raw_context, hub_client, request_id)
       when is_map(raw_context) and is_binary(request_id) do
    %Context{
      __hub_client__: hub_client,
      organization_id: raw_context["organization_id"],
      request_id: request_id
    }
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
      hub_client = get_hub_client(socket)
      context = build_context(message["context"] || %{}, hub_client, request_id)

      args = %{
        credential: message["credential"] || %{},
        extra: message["extra"] || %{},
        context: context
      }

      CallbackRunner.dispatch(
        cred_def.authenticate,
        args,
        task_supervisor: socket.assigns.task_supervisor,
        context: context,
        ok_event: :credential_auth_spec_response,
        error_event: :credential_auth_spec_error,
        topic: topic,
        run_opts: [
          label: "credential '#{cred_def.name}' authentication",
          timeout_ms: @credential_auth_timeout_ms,
          invalid_callback_error:
            SdkError.new(
              :invalid_credential_authenticate,
              "authenticate must be a function with arity 1"
            )
        ]
      )

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

  defp handle_oauth2_build_authorize_url(socket, topic, message) do
    with {:ok, request_id} <- extract_request_id(message),
         {:ok, credential_name} <- extract_credential_name(message),
         {:ok, cred_def} <- find_credential_for_auth(socket, credential_name) do
      hub_client = get_hub_client(socket)
      context = build_context(message["context"] || %{}, hub_client, request_id)

      args = %{
        credential: message["credential"] || %{},
        redirect_uri: message["redirect_uri"],
        state: message["state"],
        context: context
      }

      CallbackRunner.dispatch(
        cred_def.oauth2_build_authorize_url,
        args,
        task_supervisor: socket.assigns.task_supervisor,
        context: context,
        ok_event: :oauth2_build_authorize_url_response,
        error_event: :oauth2_build_authorize_url_error,
        topic: topic,
        run_opts: [
          label: "credential '#{cred_def.name}' oauth2_build_authorize_url",
          timeout_ms: @oauth2_timeout_ms,
          invalid_callback_error:
            SdkError.new(
              :invalid_callback,
              "oauth2_build_authorize_url must be a function with arity 1"
            )
        ]
      )

      socket
    else
      {:error, %SdkError{} = err} ->
        push(socket, topic, "oauth2_build_authorize_url_error", %{
          "request_id" => message["request_id"],
          "error" => SdkError.to_map(err)
        })

        socket
    end
  end

  defp handle_oauth2_get_token(socket, topic, message) do
    with {:ok, request_id} <- extract_request_id(message),
         {:ok, credential_name} <- extract_credential_name(message),
         {:ok, cred_def} <- find_credential_for_auth(socket, credential_name) do
      hub_client = get_hub_client(socket)
      context = build_context(message["context"] || %{}, hub_client, request_id)

      args = %{
        credential: message["credential"] || %{},
        code: message["code"],
        redirect_uri: message["redirect_uri"],
        context: context
      }

      CallbackRunner.dispatch(
        cred_def.oauth2_get_token,
        args,
        task_supervisor: socket.assigns.task_supervisor,
        context: context,
        ok_event: :oauth2_get_token_response,
        error_event: :oauth2_get_token_error,
        topic: topic,
        run_opts: [
          label: "credential '#{cred_def.name}' oauth2_get_token",
          timeout_ms: @oauth2_timeout_ms,
          invalid_callback_error:
            SdkError.new(
              :invalid_callback,
              "oauth2_get_token must be a function with arity 1"
            )
        ]
      )

      socket
    else
      {:error, %SdkError{} = err} ->
        push(socket, topic, "oauth2_get_token_error", %{
          "request_id" => message["request_id"],
          "error" => SdkError.to_map(err)
        })

        socket
    end
  end

  defp handle_oauth2_refresh_token(socket, topic, message) do
    with {:ok, request_id} <- extract_request_id(message),
         {:ok, credential_name} <- extract_credential_name(message),
         {:ok, cred_def} <- find_credential_for_auth(socket, credential_name) do
      hub_client = get_hub_client(socket)
      context = build_context(message["context"] || %{}, hub_client, request_id)

      args = %{
        credential: message["credential"] || %{},
        context: context
      }

      CallbackRunner.dispatch(
        cred_def.oauth2_refresh_token,
        args,
        task_supervisor: socket.assigns.task_supervisor,
        context: context,
        ok_event: :oauth2_refresh_token_response,
        error_event: :oauth2_refresh_token_error,
        topic: topic,
        run_opts: [
          label: "credential '#{cred_def.name}' oauth2_refresh_token",
          timeout_ms: @oauth2_timeout_ms,
          invalid_callback_error:
            SdkError.new(
              :invalid_callback,
              "oauth2_refresh_token must be a function with arity 1"
            )
        ]
      )

      socket
    else
      {:error, %SdkError{} = err} ->
        push(socket, topic, "oauth2_refresh_token_error", %{
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
      %ToolDefinition{} = tool -> {:ok, tool}
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
