defmodule AtomemoPluginSdk.Context.Files do
  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.SocketRuntime.{HubCaller, SdkError}

  @type operation_error :: :invalid_file_source | SdkError.t() | HubCaller.error()

  @doc """
  Downloads a file from OSS to memory.

  ## Options

    * `:receive_timeout` - Download timeout in milliseconds (default: 15000)
  """
  @spec download(Context.t(), FileRef.t()) :: {:ok, FileRef.t()} | {:error, operation_error()}
  @spec download(Context.t(), FileRef.t(), keyword()) ::
          {:ok, FileRef.t()} | {:error, operation_error()}
  def download(context, file_ref, opts \\ [])

  def download(_context, %FileRef{source: :mem} = file_ref, _opts) do
    {:ok, file_ref}
  end

  def download(%Context{} = context, %FileRef{source: :oss} = file_ref, opts) do
    requester = Keyword.get(opts, :requester, &do_download/2)

    with {:ok, url} <- download_url(context, file_ref),
         {:ok, response} <- requester.(url, opts) do
      updated_file_ref =
        %{file_ref | source: :mem, content: response.body, size: byte_size(response.body)}
        |> set_filename_if_needed()
        |> set_extname_if_needed()
        |> set_mime_type_if_needed(response)

      {:ok, updated_file_ref}
    end
  end

  defp set_mime_type_if_needed(%FileRef{mime_type: nil} = file_ref, response) do
    content_type = response |> Req.Response.get_header("content-type") |> List.first()

    mime_type =
      case content_type && content_type |> String.split(";") |> List.first() do
        nil -> file_ref.extension && MIME.type(file_ref.extension)
        mime_type -> mime_type |> String.trim() |> String.downcase()
      end

    %{file_ref | mime_type: mime_type}
  end

  defp set_mime_type_if_needed(file_ref, _response), do: file_ref

  defp set_filename_if_needed(%FileRef{filename: nil, res_key: res_key} = file_ref) do
    %{file_ref | filename: Path.basename(res_key)}
  end

  defp set_filename_if_needed(file_ref), do: file_ref

  defp set_extname_if_needed(%FileRef{extension: nil, res_key: res_key} = file_ref) do
    case Path.extname(res_key) do
      "" -> file_ref
      ext -> %{file_ref | extension: ext}
    end
  end

  defp set_extname_if_needed(file_ref), do: file_ref

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

  defp do_download(url, opts) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)

    case Req.get(url, retry: false, receive_timeout: timeout) do
      {:ok, %Req.Response{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error,
         SdkError.new(
           :download_error,
           "Download failed with status #{status} and #{inspect(body)}"
         )}

      {:error, reason} ->
        {:error, SdkError.new(:download_error, "Download failed with error #{inspect(reason)}")}
    end
  end
end
