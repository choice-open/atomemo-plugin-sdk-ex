defmodule AtomemoPluginSdk.Context.Files do
  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.SocketRuntime.HubCaller

  @type operation_error ::
          :invalid_file_source
          | :invalid_upload_payload
          | HubCaller.error()

  @doc """
  Gets a pre-signed URL for an OSS file by its resource key.

  ## Options

    * `:expires_in` - Request timeout in seconds (default: 3600)
  """
  @spec download_url(Context.t(), FileRef.t()) ::
          {:ok, String.t()} | {:error, operation_error()}
  @spec download_url(Context.t(), FileRef.t(), keyword()) ::
          {:ok, String.t()} | {:error, operation_error()}
  def download_url(context, file_ref, opts \\ [])

  def download_url(
        %Context{__hub_client__: hub_client},
        %FileRef{source: :oss, res_key: res_key},
        opts
      ) do
    case HubCaller.call(hub_client, "get_file_url", %{"res_key" => res_key}, opts) do
      {:ok, %{"url" => url}} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  def download_url(_context, %FileRef{source: :mem}, _opts) do
    {:error, :invalid_file_source}
  end
end
