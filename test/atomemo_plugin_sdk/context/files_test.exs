defmodule AtomemoPluginSdk.Context.FilesTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.Context.Files
  alias AtomemoPluginSdk.FileRef

  describe "download_url/3" do
    test "returns url data for oss source" do
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

      assert {:ok, "https://cdn.example.com/file.pdf"} =
               Files.download_url(context, file_ref)

      assert_receive {:hub_called_with, "path/to/file.pdf"}
    end

    test "returns invalid_file_source for mem source" do
      context = %Context{__hub_client__: self(), organization_id: ""}
      file_ref = %FileRef{source: :mem}

      assert {:error, :invalid_file_source} = Files.download_url(context, file_ref)
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
               Files.download_url(context, file_ref)
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
      file_ref = %FileRef{source: :oss, res_key: "path/to/file.pdf", mime_type: "application/custom"}

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
  end
end
