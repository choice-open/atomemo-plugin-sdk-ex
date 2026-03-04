defmodule AtomemoPluginSdk.SocketRuntime.HubClientTest do
  use ExUnit.Case
  use Slipstream.SocketTest

  alias AtomemoPluginSdk.PluginDefinition
  alias AtomemoPluginSdk.SocketRuntime.HubClient

  defmodule TestPluginModule do
    def definition do
      PluginDefinition.new(%{
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

    on_exit(fn ->
      System.delete_env("HUB_WS_URL")
      System.delete_env("HUB_MODE")
      System.delete_env("HUB_DEBUG_API_KEY")
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
        start_supervised!(
          {HubClient,
           [
             plugin_module: TestPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      # Accept the connection
      accept_connect(client)

      # Assert client joins the debug topic
      assert_join("debug_plugin:test_plugin", %{}, :ok)

      # Assert client pushes register_plugin with the full plugin definition
      assert_push("debug_plugin:test_plugin", "register_plugin", plugin, ref)

      # Verify plugin structure (in test mode, Slipstream may pass struct directly)
      assert %PluginDefinition{name: "test_plugin", lang: :elixir} = plugin

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
        start_supervised!(
          {HubClient,
           [
             plugin_module: TestPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      # Accept the connection
      accept_connect(client)

      # Assert client joins the release topic
      assert_join("release_plugin:test_plugin__release__1.0.0", %{}, :ok)
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
        start_supervised!(
          {HubClient,
           [
             plugin_module: TestPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

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
        def definition do
          PluginDefinition.new(%{
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
                invoke: fn _params, _credentials ->
                  {:error, %{"message" => "Something went wrong"}}
                end
              }
            ]
          })
        end
      end

      # Capture expected error log to avoid cluttering test output
      ExUnit.CaptureLog.capture_log(fn ->
        client =
          start_supervised!(
            {HubClient,
             [
               plugin_module: ErrorPluginModule,
               test_mode?: true,
               task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
             ]}
          )

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
            "error" => %{"message" => "Something went wrong"}
          },
          _
        )
      end)
    end

    test "handles tool with invoke/1 callback (single argument)" do
      defmodule SingleArgPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "single_arg_plugin",
            display_name: %{"en_US" => "Single Arg Plugin"},
            description: %{"en_US" => "A plugin with single arg invoke"},
            icon: "🔧",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "single_arg_tool",
                display_name: %{"en_US" => "Single Arg Tool"},
                description: %{"en_US" => "Tool with invoke/1"},
                icon: "🔧",
                parameters: [],
                invoke: fn args ->
                  {:ok,
                   %{
                     "params" => args.parameters,
                     "creds" => args.credentials,
                     "message" => "Single arg invoke"
                   }}
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
             plugin_module: SingleArgPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:single_arg_plugin", %{}, :ok)

      assert_push("debug_plugin:single_arg_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:single_arg_plugin", "invoke_tool", %{
        "request_id" => "req_789",
        "tool_name" => "single_arg_tool",
        "parameters" => %{"input" => "test"},
        "credentials" => %{"api_key" => "secret"}
      })

      assert_push(
        "debug_plugin:single_arg_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_789",
          "data" => %{
            "params" => %{"input" => "test"},
            "creds" => %{"api_key" => "secret"},
            "message" => "Single arg invoke"
          }
        },
        _
      )
    end

    test "handles tool with invoke/2 callback (two arguments)" do
      defmodule TwoArgsPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "two_args_plugin",
            display_name: %{"en_US" => "Two Args Plugin"},
            description: %{"en_US" => "A plugin with two args invoke"},
            icon: "🔧",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "two_args_tool",
                display_name: %{"en_US" => "Two Args Tool"},
                description: %{"en_US" => "Tool with invoke/2"},
                icon: "🔧",
                parameters: [],
                invoke: fn params, credentials ->
                  {:ok,
                   %{
                     "params" => params,
                     "creds" => credentials,
                     "message" => "Two args invoke"
                   }}
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
             plugin_module: TwoArgsPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:two_args_plugin", %{}, :ok)

      assert_push("debug_plugin:two_args_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:two_args_plugin", "invoke_tool", %{
        "request_id" => "req_890",
        "tool_name" => "two_args_tool",
        "parameters" => %{"input" => "test2"},
        "credentials" => %{"token" => "bearer123"}
      })

      assert_push(
        "debug_plugin:two_args_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_890",
          "data" => %{
            "params" => %{"input" => "test2"},
            "creds" => %{"token" => "bearer123"},
            "message" => "Two args invoke"
          }
        },
        _
      )
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
        def definition do
          PluginDefinition.new(%{
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
          {HubClient,
           [
             plugin_module: AuthSpecPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
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
          "data" => %{
            "adapter" => "openai",
            "endpoint" => "https://api.openai.com/chat/completions",
            "headers" => %{}
          }
        },
        _
      )
    end

    test "handles credential_auth_spec when plugin does not implement callback" do
      defmodule NoAuthSpecPluginModule do
        def definition do
          PluginDefinition.new(%{
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

      ExUnit.CaptureLog.capture_log(fn ->
        client =
          start_supervised!(
            {HubClient,
             [
               plugin_module: NoAuthSpecPluginModule,
               test_mode?: true,
               task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
             ]}
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
          %{
            "request_id" => "auth_req_2",
            "error" => %{"code" => "sdk:not_supported", "message" => "auth_spec not supported"}
          },
          _
        )
      end)
    end

    test "handles credential_auth_spec with missing request_id" do
      defmodule MissingReqIdPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "missing_req_id_plugin",
            display_name: %{"en_US" => "Test Plugin"},
            description: %{"en_US" => "Test"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "test_cred",
                authenticate: fn _args -> {:ok, %{}} end
              }
            ],
            tools: []
          })
        end
      end

      client =
        start_supervised!(
          {HubClient,
           [
             plugin_module: MissingReqIdPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:missing_req_id_plugin", %{}, :ok)

      assert_push("debug_plugin:missing_req_id_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:missing_req_id_plugin", "credential_auth_spec", %{
        "credential_name" => "test_cred"
      })

      assert_push(
        "debug_plugin:missing_req_id_plugin",
        "credential_auth_spec_error",
        %{
          "request_id" => nil,
          "error" => %{
            "code" => "sdk:invalid_request_id",
            "message" => "request_id is required"
          }
        },
        _
      )
    end

    test "handles credential_auth_spec with missing credential_name" do
      defmodule MissingCredNamePluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "missing_cred_name_plugin",
            display_name: %{"en_US" => "Test Plugin"},
            description: %{"en_US" => "Test"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "test_cred",
                authenticate: fn _args -> {:ok, %{}} end
              }
            ],
            tools: []
          })
        end
      end

      client =
        start_supervised!(
          {HubClient,
           [
             plugin_module: MissingCredNamePluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:missing_cred_name_plugin", %{}, :ok)

      assert_push("debug_plugin:missing_cred_name_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:missing_cred_name_plugin", "credential_auth_spec", %{
        "request_id" => "auth_req_3"
      })

      assert_push(
        "debug_plugin:missing_cred_name_plugin",
        "credential_auth_spec_error",
        %{
          "request_id" => "auth_req_3",
          "error" => %{
            "code" => "sdk:invalid_credential_name",
            "message" => "credential_name is required"
          }
        },
        _
      )
    end

    test "handles credential_auth_spec with unknown credential" do
      defmodule UnknownCredPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "unknown_cred_plugin",
            display_name: %{"en_US" => "Test Plugin"},
            description: %{"en_US" => "Test"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "existing_cred",
                authenticate: fn _args -> {:ok, %{}} end
              }
            ],
            tools: []
          })
        end
      end

      client =
        start_supervised!(
          {HubClient,
           [
             plugin_module: UnknownCredPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:unknown_cred_plugin", %{}, :ok)

      assert_push("debug_plugin:unknown_cred_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:unknown_cred_plugin", "credential_auth_spec", %{
        "request_id" => "auth_req_4",
        "credential_name" => "unknown_credential"
      })

      assert_push(
        "debug_plugin:unknown_cred_plugin",
        "credential_auth_spec_error",
        %{
          "request_id" => "auth_req_4",
          "error" => %{
            "code" => "sdk:credential_not_found",
            "message" => "Credential 'unknown_credential' not found"
          }
        },
        _
      )
    end

    test "handles credential_auth_spec when authenticate callback throws error" do
      defmodule ErrorAuthPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "error_auth_plugin",
            display_name: %{"en_US" => "Error Auth Plugin"},
            description: %{"en_US" => "Plugin with error auth"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "error_cred",
                authenticate: fn _args -> {:error, "Authentication failed"} end
              }
            ],
            tools: []
          })
        end
      end

      ExUnit.CaptureLog.capture_log(fn ->
        client =
          start_supervised!(
            {HubClient,
             [
               plugin_module: ErrorAuthPluginModule,
               test_mode?: true,
               task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
             ]}
          )

        accept_connect(client)
        assert_join("debug_plugin:error_auth_plugin", %{}, :ok)

        assert_push("debug_plugin:error_auth_plugin", "register_plugin", _plugin, ref)
        reply(client, ref, :ok)

        push(client, "debug_plugin:error_auth_plugin", "credential_auth_spec", %{
          "request_id" => "auth_req_5",
          "credential_name" => "error_cred"
        })

        assert_push(
          "debug_plugin:error_auth_plugin",
          "credential_auth_spec_error",
          %{"request_id" => "auth_req_5", "error" => %{"message" => "Authentication failed"}},
          _
        )
      end)
    end
  end
end
