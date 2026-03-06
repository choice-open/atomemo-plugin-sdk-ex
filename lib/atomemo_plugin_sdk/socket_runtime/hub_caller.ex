defmodule AtomemoPluginSdk.SocketRuntime.HubCaller do
  @moduledoc """
  Provides a synchronous generic call API for Hub interactions from tool callbacks.
  """

  @default_timeout 10_000

  @typedoc """
  Error types returned by HubCaller.

  - `{:hub_error, code, message}` - Hub returned a business error
  - `:timeout` - Request timed out
  - `{:hub_client_down, reason}` - HubClient process crashed
  """
  @type error :: {:hub_error, String.t(), String.t()} | :timeout | {:hub_client_down, term()}

  @doc """
  Convenience wrapper for Hub `demo_hub_call` event.
  """
  @spec demo_hub_call(pid() | atom(), String.t(), keyword()) :: {:ok, map()} | {:error, error()}
  def demo_hub_call(hub_client, result, opts \\ []) when is_binary(result) do
    call(hub_client, "demo_hub_call", %{"result" => result}, opts)
  end

  @doc """
  Sends a generic hub event and waits for response.

  ## Options

    * `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})
  """
  @spec call(pid() | atom(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, error()}
  def call(hub_client, event, payload, opts \\ [])
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
