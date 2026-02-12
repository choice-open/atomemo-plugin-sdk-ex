defmodule AtomemoPluginSdk.SocketRuntimeTest do
  use ExUnit.Case
  use Slipstream.SocketTest

  alias AtomemoPluginSdk.{PluginDefinition, SocketRuntime}

  defmodule TestPluginModule do
    def definition(organization_id) do
      PluginDefinition.new(%{
        organization_id: organization_id,
        lang: :elixir,
        name: "test_plugin",
        display_name: %{"en_US" => "Test Plugin"},
        description: %{"en_US" => "A test plugin"},
        icon: "🧪",
        author: "Test Author",
        email: "test@example.com",
        version: "1.0.0",
        tools: [
          %{
            name: "test_tool",
            display_name: %{"en_US" => "Test Tool"},
            description: %{"en_US" => "A test tool"},
            icon: "🔧",
            parameters: [
              %{
                type: "string",
                name: "input",
                display_name: %{"en_US" => "Input"},
                required: true
              }
            ],
            invoke: fn params, _credentials ->
              {:ok, %{"result" => "Processed: #{params["input"]}"}}
            end
          }
        ]
      })
    end
  end

  setup do
    # Set up environment variables
    System.put_env("HUB_WS_URL", "ws://test.example.com/socket")
    System.put_env("HUB_ORGANIZATION_ID", "test_org")

    on_exit(fn ->
      System.delete_env("HUB_WS_URL")
      System.delete_env("HUB_MODE")
      System.delete_env("HUB_DEBUG_API_KEY")
      System.delete_env("HUB_ORGANIZATION_ID")
    end)

    :ok
  end

  describe "debug mode" do
    setup do
      System.put_env("HUB_MODE", "debug")
      System.put_env("HUB_DEBUG_API_KEY", "test_api_key")
      :ok
    end

    test "successfully connects, joins topic, and registers plugin" do
      client =
        start_supervised!({SocketRuntime, [plugin_module: TestPluginModule, test_mode?: true]})

      # Accept the connection
      accept_connect(client)

      # Assert client joins the debug topic
      assert_join("debug_plugin:test_plugin", %{}, :ok)

      # Assert client pushes register_plugin with the full plugin definition
      assert_push("debug_plugin:test_plugin", "register_plugin", plugin, ref)

      # Verify plugin structure (in test mode, Slipstream may pass struct directly)
      assert %PluginDefinition{name: "test_plugin", organization_id: "test_org", lang: :elixir} =
               plugin

      # Reply with success
      reply(client, ref, :ok)
    end
  end

  describe "release mode" do
    setup do
      System.put_env("HUB_MODE", "release")
      :ok
    end

    test "successfully connects and joins topic (join success means claim success)" do
      client =
        start_supervised!({SocketRuntime, [plugin_module: TestPluginModule, test_mode?: true]})

      # Accept the connection
      accept_connect(client)

      # Assert client joins the release topic
      assert_join("release_plugin:test_org__test_plugin__release__1.0.0", %{}, :ok)
    end
  end

  describe "invoke_tool" do
    setup do
      System.put_env("HUB_MODE", "debug")
      System.put_env("HUB_DEBUG_API_KEY", "test_api_key")
      :ok
    end

    test "handles invoke_tool message and responds with result" do
      client =
        start_supervised!({SocketRuntime, [plugin_module: TestPluginModule, test_mode?: true]})

      accept_connect(client)
      assert_join("debug_plugin:test_plugin", %{}, :ok)

      assert_push("debug_plugin:test_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      # Simulate server pushing invoke_tool message
      push(client, "debug_plugin:test_plugin", "invoke_tool", %{
        "request_id" => "req_123",
        "tool_name" => "test_tool",
        "parameters" => %{"input" => "hello"}
      })

      # Assert client responds with invoke_tool_response
      assert_push(
        "debug_plugin:test_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_123",
          "data" => %{"result" => "Processed: hello"}
        },
        _
      )
    end

    test "handles invoke_tool error and responds with error" do
      defmodule ErrorPluginModule do
        def definition(organization_id) do
          PluginDefinition.new(%{
            organization_id: organization_id,
            lang: :elixir,
            name: "error_plugin",
            display_name: %{"en_US" => "Error Plugin"},
            description: %{"en_US" => "A plugin that errors"},
            icon: "❌",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "error_tool",
                display_name: %{"en_US" => "Error Tool"},
                description: %{"en_US" => "A tool that errors"},
                icon: "🔧",
                parameters: [],
                invoke: fn _params, _credentials -> {:error, "Something went wrong"} end
              }
            ]
          })
        end
      end

      # Capture expected error log to avoid cluttering test output
      ExUnit.CaptureLog.capture_log(fn ->
        client =
          start_supervised!({SocketRuntime, [plugin_module: ErrorPluginModule, test_mode?: true]})

        accept_connect(client)
        assert_join("debug_plugin:error_plugin", %{}, :ok)

        assert_push("debug_plugin:error_plugin", "register_plugin", _plugin, ref)
        reply(client, ref, :ok)

        # Simulate server pushing invoke_tool message
        push(client, "debug_plugin:error_plugin", "invoke_tool", %{
          "request_id" => "req_456",
          "tool_name" => "error_tool",
          "parameters" => %{}
        })

        # Assert client responds with invoke_tool_error
        assert_push(
          "debug_plugin:error_plugin",
          "invoke_tool_error",
          %{
            "request_id" => "req_456",
            "error" => "Something went wrong"
          },
          _
        )
      end)
    end
  end

  describe "credential_auth_spec" do
    setup do
      System.put_env("HUB_MODE", "debug")
      System.put_env("HUB_DEBUG_API_KEY", "test_api_key")
      :ok
    end

    test "handles credential_auth_spec when plugin implements callback and responds with success" do
      defmodule AuthSpecPluginModule do
        def definition(organization_id) do
          PluginDefinition.new(%{
            organization_id: organization_id,
            lang: :elixir,
            name: "auth_spec_plugin",
            display_name: %{"en_US" => "Auth Spec Plugin"},
            description: %{"en_US" => "Plugin with auth_spec"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "openai",
                authenticate: fn _args ->
                  {:ok,
                   %{
                     "adapter" => "openai",
                     "endpoint" => "https://api.openai.com/chat/completions",
                     "headers" => %{}
                   }}
                end
              }
            ],
            tools: []
          })
        end
      end

      client =
        start_supervised!(
          {SocketRuntime, [plugin_module: AuthSpecPluginModule, test_mode?: true]}
        )

      accept_connect(client)
      assert_join("debug_plugin:auth_spec_plugin", %{}, :ok)

      assert_push("debug_plugin:auth_spec_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:auth_spec_plugin", "credential_auth_spec", %{
        "request_id" => "auth_req_1",
        "credential_name" => "openai",
        "credential" => %{"api_key" => "sk-xxx"},
        "extra" => %{"model" => "gpt-4"}
      })

      assert_push(
        "debug_plugin:auth_spec_plugin",
        "credential_auth_spec_response",
        %{
          "request_id" => "auth_req_1",
          "adapter" => "openai",
          "endpoint" => "https://api.openai.com/chat/completions",
          "headers" => %{}
        },
        _
      )
    end

    test "handles credential_auth_spec when plugin does not implement callback" do
      defmodule NoAuthSpecPluginModule do
        def definition(organization_id) do
          PluginDefinition.new(%{
            organization_id: organization_id,
            lang: :elixir,
            name: "no_auth_spec_plugin",
            display_name: %{"en_US" => "No Auth Spec Plugin"},
            description: %{"en_US" => "Plugin without auth_spec"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "openai"
              }
            ],
            tools: []
          })
        end
      end

      client =
        start_supervised!(
          {SocketRuntime, [plugin_module: NoAuthSpecPluginModule, test_mode?: true]}
        )

      accept_connect(client)
      assert_join("debug_plugin:no_auth_spec_plugin", %{}, :ok)

      assert_push("debug_plugin:no_auth_spec_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:no_auth_spec_plugin", "credential_auth_spec", %{
        "request_id" => "auth_req_2",
        "credential_name" => "openai",
        "credential" => %{},
        "extra" => %{}
      })

      assert_push(
        "debug_plugin:no_auth_spec_plugin",
        "credential_auth_spec_error",
        %{"request_id" => "auth_req_2", "error" => "auth_spec not supported"},
        _
      )
    end
  end
end
