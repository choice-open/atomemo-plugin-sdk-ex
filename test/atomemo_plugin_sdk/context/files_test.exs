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
end
