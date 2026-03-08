defmodule AtomemoPluginSdk.Context.FilesTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.Context.Files
  alias AtomemoPluginSdk.FileRef

  describe "attach_download_url/3" do
    test "returns file_ref with remote_url for oss source" do
      parent = self()

      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => res_key}, from} ->
              send(parent, {:hub_called_with, res_key})

              send(
                from,
                {:hub_call_response, request_id, %{"url" => "https://cdn.example.com/file.pdf"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "path/to/file.pdf"}

      assert {:ok, %FileRef{} = result} =
               Files.attach_download_url(context, file_ref)

      assert result.remote_url == "https://cdn.example.com/file.pdf"
      assert result.res_key == "path/to/file.pdf"

      assert_receive {:hub_called_with, "path/to/file.pdf"}
    end

    test "returns sdk invalid_operation error for mem source" do
      context = %Context{__hub_client__: self(), organization_id: ""}
      file_ref = %FileRef{source: :mem}

      assert {:error, %SdkError{code: :invalid_operation}} =
               Files.attach_download_url(context, file_ref)
    end

    test "propagates hub error for oss source" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_error, request_id, %{"code" => "forbidden", "message" => "no access"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "private/file.pdf"}

      assert {:error, {:hub_error, "forbidden", "no access"}} =
               Files.attach_download_url(context, file_ref)
    end
  end

  describe "download/3" do
    test "returns mem file_ref unchanged for mem source" do
      context = %Context{__hub_client__: self(), organization_id: ""}
      file_ref = %FileRef{source: :mem, content: "abc"}

      assert {:ok, ^file_ref} = Files.download(context, file_ref)
    end

    test "normalizes oss source to mem source" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_response, request_id, %{"url" => "https://example.test/download"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "path/to/file.pdf", filename: "file.pdf"}

      response = %Req.Response{
        status: 200,
        body: "abc",
        headers: %{"content-type" => ["application/pdf"]}
      }

      requester = fn _url, _opts -> {:ok, response} end

      assert {:ok, %FileRef{} = result} =
               Files.download(context, file_ref, requester: requester)

      assert result.source == :mem
      assert result.res_key == "path/to/file.pdf"
      assert result.filename == "file.pdf"
    end

    test "performs real GET download for oss source via Req" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_response, request_id, %{"url" => "http://localhost"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "path/to/file.pdf", filename: "file.pdf"}

      response = %Req.Response{status: 200, body: "downloaded-bytes", headers: %{}}
      requester = fn _url, _opts -> {:ok, response} end

      assert {:ok, %FileRef{} = result} =
               Files.download(context, file_ref, requester: requester)

      assert result.source == :mem
      assert result.content == "downloaded-bytes"
      assert result.size == byte_size("downloaded-bytes")
    end

    test "propagates hub error when download url fetch fails" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_error, request_id, %{"code" => "forbidden", "message" => "no access"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "private/file.pdf"}

      assert {:error, {:hub_error, "forbidden", "no access"}} =
               Files.download(context, file_ref)
    end

    test "propagates requester error when download fails" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_response, request_id, %{"url" => "https://example.test/download"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "path/to/file.txt"}
      requester = fn _url, _opts -> {:error, :request_failed} end

      assert {:error, :request_failed} = Files.download(context, file_ref, requester: requester)
    end

    test "infers filename extension and mime_type from res_key when missing" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_response, request_id, %{"url" => "https://example.test/download"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "path/to/report.csv"}
      response = %Req.Response{status: 200, body: "a,b\n1,2", headers: %{}}
      requester = fn _url, _opts -> {:ok, response} end

      assert {:ok, %FileRef{} = result} = Files.download(context, file_ref, requester: requester)

      assert result.filename == "report.csv"
      assert result.extension == ".csv"
      assert result.mime_type == MIME.type(".csv")
    end

    test "keeps existing mime_type even when response has content-type header" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_file_url", request_id, %{"res_key" => _res_key}, from} ->
              send(
                from,
                {:hub_call_response, request_id, %{"url" => "https://example.test/download"}}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}

      file_ref = %FileRef{
        source: :oss,
        res_key: "path/to/file.pdf",
        mime_type: "application/custom"
      }

      response = %Req.Response{
        status: 200,
        body: "abc",
        headers: %{"content-type" => ["application/pdf; charset=utf-8"]}
      }

      requester = fn _url, _opts -> {:ok, response} end

      assert {:ok, %FileRef{} = result} = Files.download(context, file_ref, requester: requester)
      assert result.mime_type == "application/custom"
    end
  end

  describe "upload/3" do
    test "returns oss file_ref unchanged for oss source" do
      context = %Context{__hub_client__: self(), organization_id: ""}
      file_ref = %FileRef{source: :oss, res_key: "already/oss.pdf"}

      assert {:ok, ^file_ref} = Files.upload(context, file_ref)
    end

    test "normalizes mem source to oss source" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_upload_url", request_id, _payload, from} ->
              send(
                from,
                {:hub_call_response, request_id,
                 %{
                   "presigned_url" => "https://example.test/upload",
                   "res_key" => "uploads/res-key-2"
                 }}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :mem, filename: "draft.txt", content: "hello"}

      requester = fn _url, _content, _opts -> :ok end

      assert {:ok, %FileRef{} = result} =
               Files.upload(context, file_ref, requester: requester)

      assert result.source == :oss
      assert result.filename == "draft.txt"
      assert result.content == nil
      assert is_binary(result.res_key)
      assert result.res_key != ""
    end

    test "performs real PUT upload for mem source via Req" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_upload_url", request_id, payload, from} ->
              assert payload["mime_type"] == "text/plain"
              refute Map.has_key?(payload, "filename")
              refute Map.has_key?(payload, "size")

              send(
                from,
                {:hub_call_response, request_id,
                 %{
                   "presigned_url" => "http://localhost",
                   "res_key" => "uploads/res-key-1"
                 }}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}

      file_ref = %FileRef{
        source: :mem,
        filename: "draft.txt",
        mime_type: "text/plain",
        content: "upload-bytes"
      }

      requester = fn _url, content, _opts ->
        assert content == "upload-bytes"
        :ok
      end

      assert {:ok, %FileRef{} = result} =
               Files.upload(context, file_ref, requester: requester)

      assert result.source == :oss
      assert result.res_key == "uploads/res-key-1"
      assert result.content == nil
      assert result.size == byte_size("upload-bytes")
    end

    test "passes mime_type as content_type option to uploader" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_upload_url", request_id, _payload, from} ->
              send(
                from,
                {:hub_call_response, request_id,
                 %{
                   "presigned_url" => "https://example.test/upload",
                   "res_key" => "uploads/res-key-3"
                 }}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}

      file_ref = %FileRef{
        source: :mem,
        filename: "draft.txt",
        mime_type: "text/plain",
        content: "upload-bytes"
      }

      requester = fn _url, _content, opts ->
        assert opts[:content_type] == "text/plain"
        :ok
      end

      assert {:ok, %FileRef{source: :oss}} = Files.upload(context, file_ref, requester: requester)
    end

    test "passes key_prefix to get_upload_url payload" do
      hub_client =
        spawn(fn ->
          receive do
            {:hub_call, "get_upload_url", request_id, payload, from} ->
              assert payload["key_prefix"] == "plugins/avatar/"

              send(
                from,
                {:hub_call_response, request_id,
                 %{
                   "presigned_url" => "https://example.test/upload",
                   "res_key" => "uploads/res-key-4"
                 }}
              )
          end
        end)

      context = %Context{__hub_client__: hub_client, organization_id: ""}
      file_ref = %FileRef{source: :mem, filename: "draft.txt", content: "hello"}
      requester = fn _url, _content, _opts -> :ok end

      assert {:ok, %FileRef{source: :oss}} =
               Files.upload(context, file_ref,
                 requester: requester,
                 key_prefix: "plugins/avatar/"
               )
    end
  end
end
