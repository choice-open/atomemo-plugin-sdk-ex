defmodule AtomemoPluginSdk.SocketRuntime.HubCallerTest do
  use ExUnit.Case
  use Slipstream.SocketTest

  import ExUnit.CaptureLog

  alias AtomemoPluginSdk.PluginDefinition
  alias AtomemoPluginSdk.SocketRuntime.{HubClient, HubCaller}

  defmodule TestPluginModule do
    def definition do
      PluginDefinition.new(%{
        lang: :elixir,
        name: "hub_caller_test_plugin",
        display_name: %{"en_US" => "Hub Caller Test Plugin"},
        description: %{"en_US" => "A test plugin for HubCaller"},
        icon: "🧪",
        author: "Test Author",
        email: "test@example.com",
        version: "1.0.0",
        tools: []
      })
    end
  end

  setup do
    System.put_env("HUB_WS_URL", "ws://test.example.com/socket")
    System.put_env("HUB_MODE", "debug")
    System.put_env("HUB_DEBUG_API_KEY", "test_api_key")

    on_exit(fn ->
      System.delete_env("HUB_WS_URL")
      System.delete_env("HUB_MODE")
      System.delete_env("HUB_DEBUG_API_KEY")
    end)

    :ok
  end

  defp setup_connected_client(_context) do
    client =
      start_supervised!(
        {HubClient,
         [
           plugin_module: TestPluginModule,
           test_mode?: true,
           task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
         ]}
      )

    accept_connect(client)
    assert_join("debug_plugin:hub_caller_test_plugin", %{}, :ok)
    assert_push("debug_plugin:hub_caller_test_plugin", "register_plugin", _plugin, ref)
    reply(client, ref, :ok)

    %{client: client}
  end

  describe "call/4" do
    setup :setup_connected_client

    test "returns {:ok, data} on successful response", %{client: client} do
      task =
        Task.async(fn ->
          HubCaller.call(client, "get_file_url", %{"res_key" => "path/to/file.pdf"})
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:get_file_url", payload, _ref)
      assert payload["data"] == %{"res_key" => "path/to/file.pdf"}
      request_id = payload["request_id"]

      push(client, "debug_plugin:hub_caller_test_plugin", "hub_call_response", %{
        "request_id" => request_id,
        "data" => %{"url" => "https://example.com/presigned/file.pdf"}
      })

      assert {:ok, %{"url" => "https://example.com/presigned/file.pdf"}} = Task.await(task)
    end

    test "returns {:error, {:hub_error, code, message}} on error response", %{client: client} do
      task =
        Task.async(fn ->
          HubCaller.call(client, "get_file_url", %{"res_key" => "invalid/key"})
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:get_file_url", payload, _ref)
      request_id = payload["request_id"]

      push(client, "debug_plugin:hub_caller_test_plugin", "hub_call_error", %{
        "request_id" => request_id,
        "error" => %{"code" => "not_found", "message" => "File not found"}
      })

      assert {:error, {:hub_error, "not_found", "File not found"}} = Task.await(task)
    end

    test "returns {:error, :timeout} when Hub does not respond", %{client: client} do
      task =
        Task.async(fn ->
          HubCaller.call(client, "get_file_url", %{"res_key" => "slow/file.pdf"}, timeout: 50)
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:get_file_url", _payload, _ref)

      assert {:error, :timeout} = Task.await(task)
    end

    test "returns {:error, {:hub_client_down, _}} when HubClient crashes", %{client: client} do
      task =
        Task.async(fn ->
          HubCaller.call(client, "get_file_url", %{"res_key" => "path/to/file.pdf"},
            timeout: 5_000
          )
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:get_file_url", _payload, _ref)

      capture_log(fn ->
        Process.exit(client, :kill)
        assert {:error, {:hub_client_down, :killed}} = Task.await(task)
        Process.sleep(50)
      end)
    end

    test "supports concurrent calls", %{client: client} do
      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            HubCaller.call(client, "get_file_url", %{"res_key" => "file_#{i}.pdf"})
          end)
        end

      payloads =
        for _i <- 1..3 do
          assert_push(
            "debug_plugin:hub_caller_test_plugin",
            "hub_call:get_file_url",
            payload,
            _ref
          )

          payload
        end

      for payload <- payloads do
        res_key = payload["data"]["res_key"]
        request_id = payload["request_id"]

        push(client, "debug_plugin:hub_caller_test_plugin", "hub_call_response", %{
          "request_id" => request_id,
          "data" => %{"url" => "https://example.com/#{res_key}"}
        })
      end

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, %{"url" => url}} -> String.starts_with?(url, "https://example.com/file_")
             end)
    end

    test "cleans up pending_hub_calls on timeout", %{client: client} do
      _task =
        Task.async(fn ->
          HubCaller.call(client, "get_file_url", %{"res_key" => "timeout/file.pdf"}, timeout: 50)
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:get_file_url", _payload, _ref)

      Process.sleep(150)

      state = :sys.get_state(client)
      assert state.assigns.pending_hub_calls == %{}
    end
  end

  describe "demo_hub_call/3" do
    setup :setup_connected_client

    test "sends demo_hub_call event and returns response data", %{client: client} do
      task =
        Task.async(fn ->
          HubCaller.demo_hub_call(client, "ok-demo")
        end)

      assert_push("debug_plugin:hub_caller_test_plugin", "hub_call:demo_hub_call", payload, _ref)
      assert payload["data"] == %{"result" => "ok-demo"}
      request_id = payload["request_id"]

      push(client, "debug_plugin:hub_caller_test_plugin", "hub_call_response", %{
        "request_id" => request_id,
        "data" => %{"echo" => "ok-demo"}
      })

      assert {:ok, %{"echo" => "ok-demo"}} = Task.await(task)
    end
  end

  describe "integration with invoke_tool" do
    test "tool can call Hub via args.context.__hub_client__" do
      defmodule HubCallerToolPlugin do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "hub_caller_tool_plugin",
            display_name: %{"en_US" => "Hub Caller Tool Plugin"},
            description: %{"en_US" => "Plugin with tool that calls Hub"},
            icon: "🔧",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "fetch_file_url",
                display_name: %{"en_US" => "Fetch File URL"},
                description: %{"en_US" => "Fetches file URL from Hub"},
                icon: "📁",
                parameters: [
                  %{
                    type: "string",
                    name: "res_key",
                    display_name: %{"en_US" => "Resource Key"},
                    required: true
                  }
                ],
                invoke: fn args ->
                  case HubCaller.call(
                         args.context.__hub_client__,
                         "get_file_url",
                         %{"res_key" => args.parameters["res_key"]}
                       ) do
                    {:ok, data} ->
                      {:ok, data}

                    {:error, {:hub_error, code, msg}} ->
                      {:error, %{"code" => code, "message" => msg}}

                    {:error, error} ->
                      {:error, %{"message" => inspect(error)}}
                  end
                end
              }
            ]
          })
        end
      end

      client =
        start_supervised!(
          {HubClient,
           [
             plugin_module: HubCallerToolPlugin,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:hub_caller_tool_plugin", %{}, :ok)
      assert_push("debug_plugin:hub_caller_tool_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:hub_caller_tool_plugin", "invoke_tool", %{
        "request_id" => "req_001",
        "tool_name" => "fetch_file_url",
        "parameters" => %{"res_key" => "my/doc.pdf"}
      })

      assert_push(
        "debug_plugin:hub_caller_tool_plugin",
        "hub_call:get_file_url",
        payload,
        _ref,
        1_000
      )

      assert payload["data"] == %{"res_key" => "my/doc.pdf"}
      request_id = payload["request_id"]

      push(client, "debug_plugin:hub_caller_tool_plugin", "hub_call_response", %{
        "request_id" => request_id,
        "data" => %{"url" => "https://cdn.example.com/my/doc.pdf"}
      })

      assert_push(
        "debug_plugin:hub_caller_tool_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_001",
          "data" => %{"url" => "https://cdn.example.com/my/doc.pdf"}
        },
        _,
        1_000
      )
    end
  end
end
