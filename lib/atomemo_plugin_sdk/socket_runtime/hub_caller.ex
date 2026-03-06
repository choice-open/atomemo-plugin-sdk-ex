defmodule AtomemoPluginSdk.SocketRuntime.HubCaller do
  @moduledoc """
  Provides synchronous API for calling Hub from within tool invoke callbacks.

  Supports multiple and concurrent calls within a single tool invocation.
  """

  @default_timeout 10_000

  def demo_hub_call(hub_client, result, opts \\ []) when is_binary(result) do
    call(hub_client, "demo_hub_call", %{"result" => result}, opts)
  end

  def invoke_llm(hub_client, llm_config, messages, organization_id) do
    call(
      hub_client,
      "invoke_llm",
      %{
        llm_config: llm_config,
        messages: messages,
        organization_id: organization_id
      },
      timeout: :timer.minutes(15)
    )
  end

  @typedoc """
  Error types returned by HubCaller functions.

  - `{:hub_error, code, message}` - Hub returned a business error
  - `:timeout` - Request timed out
  - `{:hub_client_down, reason}` - HubClient process crashed
  """
  @type error :: {:hub_error, String.t(), String.t()} | :timeout | {:hub_client_down, term()}

  @doc """
  Gets a presigned URL for an OSS file by its resource key.

  ## Options

    * `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})

  ## Examples

      {:ok, %{"url" => url}} = HubCaller.get_file_url(hub_client, "path/to/file.pdf")
      {:ok, %{"url" => url}} = HubCaller.get_file_url(hub_client, "path/to/file.pdf", timeout: 10_000)

      # Error handling
      case HubCaller.get_file_url(hub_client, res_key) do
        {:ok, data} -> data["url"]
        {:error, {:hub_error, code, msg}} -> handle_hub_error(code, msg)
        {:error, :timeout} -> handle_timeout()
        {:error, {:hub_client_down, _}} -> handle_disconnect()
      end

  """
  @spec get_file_url(pid() | atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, error()}
  def get_file_url(hub_client, res_key, opts \\ []) when is_binary(res_key) do
    call(hub_client, "get_file_url", %{"res_key" => res_key}, opts)
  end

  defp call(hub_client, event, payload, opts)
       when is_binary(event) and is_map(payload) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    request_id = Ecto.UUID.generate()
    monitor_ref = Process.monitor(hub_client)

    send(hub_client, {:hub_call, event, request_id, payload, self()})

    result =
      receive do
        {:hub_call_response, ^request_id, data} ->
          {:ok, data}

        {:hub_call_error, ^request_id, %{"code" => code, "message" => message}} ->
          {:error, {:hub_error, code, message}}

        {:hub_call_error, ^request_id, error} ->
          {:error, {:hub_error, "unknown", inspect(error)}}

        {:DOWN, ^monitor_ref, :process, ^hub_client, reason} ->
          {:error, {:hub_client_down, reason}}
      after
        timeout ->
          send(hub_client, {:hub_call_cancel, request_id})
          {:error, :timeout}
      end

    Process.demonitor(monitor_ref, [:flush])
    result
  end
end
