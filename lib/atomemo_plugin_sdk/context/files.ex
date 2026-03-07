defmodule AtomemoPluginSdk.Context.Files do
  @moduledoc """
  `Context` 里的文件操作入口，围绕 `FileRef` 提供统一的上传、下载与 URL 附加能力。

  该模块的核心目标是让插件作者只处理 `FileRef`，不直接关心底层对象存储细节：
  """

  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.SdkError
  alias AtomemoPluginSdk.SocketRuntime.HubCaller

  @type operation_error :: SdkError.t() | HubCaller.error()

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

    with {:ok, %FileRef{remote_url: url}} <- attach_download_url(context, file_ref),
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
  Uploads a file from memory to OSS.

  ## Options

    * `:receive_timeout` - Upload timeout in milliseconds (default: 60000)
    * `:key_prefix` - Optional key prefix for uploaded file object

  """
  @spec upload(Context.t(), FileRef.t()) ::
          {:ok, FileRef.t()} | {:error, operation_error()}
  @spec upload(Context.t(), FileRef.t(), keyword()) ::
          {:ok, FileRef.t()} | {:error, operation_error()}
  def upload(context, file_ref, opts \\ [])

  def upload(%Context{} = _context, %FileRef{source: :oss} = file_ref, _opts) do
    {:ok, file_ref}
  end

  def upload(%Context{__hub_client__: hub_client}, %FileRef{source: :mem} = file_ref, opts) do
    requester = Keyword.get(opts, :requester, &do_upload/3)
    content = file_ref.content || ""

    mime_type =
      file_ref.mime_type || MIME.type(file_ref.extension || "") || "application/octet-stream"

    upload_payload =
      %{
        "mime_type" => mime_type,
        "key_prefix" => opts[:key_prefix]
      }

    with {:ok, %{"presigned_url" => presigned_url, "res_key" => res_key}} <-
           HubCaller.call(hub_client, "get_upload_url", upload_payload),
         :ok <- requester.(presigned_url, content, Keyword.put(opts, :content_type, mime_type)) do
      {:ok,
       %FileRef{
         file_ref
         | source: :oss,
           content: nil,
           size: byte_size(content),
           res_key: res_key,
           remote_url: nil
       }}
    else
      {:ok, _} ->
        {:error,
         SdkError.new(:upload_error, "Hub call succeeded but response is missing required fields")}

      err ->
        err
    end
  end

  @doc """
  Attach a pre-signed URL to oss FileRef.

  ## Options

    * `:expires_in` - Request timeout in seconds (default: 3600)
  """
  @spec attach_download_url(Context.t(), FileRef.t()) ::
          {:ok, FileRef.t()} | {:error, operation_error()}
  @spec attach_download_url(Context.t(), FileRef.t(), keyword()) ::
          {:ok, FileRef.t()} | {:error, operation_error()}
  def attach_download_url(context, file_ref, opts \\ [])

  def attach_download_url(
        %Context{__hub_client__: hub_client},
        %FileRef{source: :oss, res_key: res_key} = file_ref,
        opts
      ) do
    case HubCaller.call(hub_client, "get_file_url", %{"res_key" => res_key}, opts) do
      {:ok, %{"url" => url}} -> {:ok, %{file_ref | remote_url: url}}
      {:error, reason} -> {:error, reason}
    end
  end

  def attach_download_url(_context, %FileRef{source: :mem}, _opts) do
    {:error,
     SdkError.new(
       :invalid_operation,
       "Cannot attach download URL to a file that is already in memory"
     )}
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

  defp do_upload(presigned_url, content, opts) do
    opts =
      [
        retry: false,
        body: content,
        receive_timeout: Keyword.get(opts, :receive_timeout, 60_000),
        headers: %{"content-type" => opts[:content_type]}
      ]

    case Req.put(presigned_url, opts) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error,
         SdkError.new(
           :upload_error,
           "Upload failed with status #{status} and #{inspect(body)}"
         )}

      {:error, reason} ->
        {:error, SdkError.new(:upload_error, "Upload failed with error #{inspect(reason)}")}
    end
  end
end
