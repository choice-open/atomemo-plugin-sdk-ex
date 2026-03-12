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
            invoke: fn args ->
              {:ok, %{"result" => "Processed: #{args.parameters["input"]}"}}
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
        "parameters" => %{"input" => "hello"},
        "context" => %{"organization_id" => "org_123"}
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
                invoke: fn _args ->
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
          "parameters" => %{},
          "context" => %{"organization_id" => "org_456"}
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
                     "has_context_key" => Map.has_key?(args, :context),
                     "organization_id" => args.context.organization_id,
                     "has_context_hub_client" => is_pid(args.context.__hub_client__),
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
        "credentials" => %{"api_key" => "secret"},
        "context" => %{"organization_id" => "org_123"}
      })

      assert_push(
        "debug_plugin:single_arg_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_789",
          "data" => %{
            "params" => %{"input" => "test"},
            "creds" => %{"api_key" => "secret"},
            "has_context_key" => true,
            "organization_id" => "org_123",
            "has_context_hub_client" => true,
            "message" => "Single arg invoke"
          }
        },
        _
      )
    end

    test "falls back to empty maps when parameters and credentials are missing" do
      defmodule MissingPayloadPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "missing_payload_plugin",
            display_name: %{"en_US" => "Missing Payload Plugin"},
            description: %{"en_US" => "A plugin for fallback payload behavior"},
            icon: "🔧",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "missing_payload_tool",
                display_name: %{"en_US" => "Missing Payload Tool"},
                description: %{"en_US" => "Tool for fallback payload behavior"},
                icon: "🔧",
                parameters: [],
                invoke: fn args ->
                  {:ok,
                   %{
                     "params" => args.parameters,
                     "creds" => args.credentials,
                     "has_context_key" => Map.has_key?(args, :context),
                     "organization_id" => args.context.organization_id,
                     "has_context_hub_client" => is_pid(args.context.__hub_client__)
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
             plugin_module: MissingPayloadPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:missing_payload_plugin", %{}, :ok)

      assert_push("debug_plugin:missing_payload_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:missing_payload_plugin", "invoke_tool", %{
        "request_id" => "req_missing",
        "tool_name" => "missing_payload_tool",
        "context" => %{"organization_id" => "org_123"}
      })

      assert_push(
        "debug_plugin:missing_payload_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_missing",
          "data" => %{
            "params" => %{},
            "creds" => %{},
            "has_context_key" => true,
            "organization_id" => "org_123",
            "has_context_hub_client" => true
          }
        },
        _
      )
    end

    test "hydrates nested SDK structs before invoking the tool callback" do
      defmodule HydratedToolPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "hydrated_tool_plugin",
            display_name: %{"en_US" => "Hydrated Tool Plugin"},
            description: %{"en_US" => "Plugin that expects hydrated structs"},
            icon: "🔧",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            tools: [
              %{
                name: "hydrated_tool",
                display_name: %{"en_US" => "Hydrated Tool"},
                description: %{"en_US" => "Tool for hydration"},
                icon: "🔧",
                parameters: [],
                invoke: fn args ->
                  file_ref = args.parameters["file"]
                  llm_config = args.parameters["llm_config"]
                  nested_file_ref = args.credentials["nested"]["file"]

                  {:ok,
                   %{
                     "file_ref?" => match?(%AtomemoPluginSdk.FileRef{}, file_ref),
                     "llm_config?" => match?(%AtomemoPluginSdk.LLMConfig{}, llm_config),
                     "nested_file_ref?" => match?(%AtomemoPluginSdk.FileRef{}, nested_file_ref),
                     "file_source" => Atom.to_string(file_ref.source),
                     "file_content" => file_ref.content,
                     "model" => llm_config.model,
                     "structured_outputs" => llm_config.model_params.structured_outputs
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
             plugin_module: HydratedToolPluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:hydrated_tool_plugin", %{}, :ok)

      assert_push("debug_plugin:hydrated_tool_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:hydrated_tool_plugin", "invoke_tool", %{
        "request_id" => "req_hydrated_tool",
        "tool_name" => "hydrated_tool",
        "parameters" => %{
          "file" => %{
            "__type__" => "file_ref",
            "source" => "mem",
            "filename" => "hello.txt",
            "content" => Base.encode64("hello")
          },
          "llm_config" => %{
            "__type__" => "llm_config",
            "version_slug" => "demo_plugin__release__1.0.0",
            "model" => "gpt-4.1",
            "model_params" => %{"structured_outputs" => true}
          }
        },
        "credentials" => %{
          "nested" => %{
            "file" => %{
              "__type__" => "file_ref",
              "source" => "oss",
              "res_key" => "docs/manual.pdf"
            }
          }
        },
        "context" => %{"organization_id" => "org_789"}
      })

      assert_push(
        "debug_plugin:hydrated_tool_plugin",
        "invoke_tool_response",
        %{
          "request_id" => "req_hydrated_tool",
          "data" => %{
            "file_ref?" => true,
            "llm_config?" => true,
            "nested_file_ref?" => true,
            "file_source" => "mem",
            "file_content" => "hello",
            "model" => "gpt-4.1",
            "structured_outputs" => true
          }
        },
        _
      )
    end

    test "returns invoke_tool_error when parameter hydration fails" do
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

      push(client, "debug_plugin:test_plugin", "invoke_tool", %{
        "request_id" => "req_invalid_hydration",
        "tool_name" => "test_tool",
        "parameters" => %{
          "input" => %{
            "__type__" => "file_ref",
            "filename" => "missing-source.txt"
          }
        },
        "context" => %{"organization_id" => "org_123"}
      })

      assert_push("debug_plugin:test_plugin", "invoke_tool_error", payload, _)

      assert payload["request_id"] == "req_invalid_hydration"
      assert payload["error"]["code"] == "sdk:invalid_parameter"

      assert payload["error"]["message"] =~
               "Failed to hydrate parameter: could not perform insert because changeset is invalid"
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
                authenticate: fn args ->
                  {:ok,
                   %{
                     "adapter" => "openai",
                     "endpoint" => "https://api.openai.com/chat/completions",
                     "headers" => %{
                       "x-api-key" => args.credential["api_key"]
                     }
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
            "headers" => %{"x-api-key" => "sk-xxx"}
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
            "error" => %{
              "code" => "sdk:invalid_credential_authenticate",
              "message" => "authenticate must be a function with arity 1"
            }
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

  describe "oauth2 callbacks" do
    setup do
      System.put_env("HUB_MODE", "debug")
      System.put_env("HUB_DEBUG_API_KEY", "test_api_key")
      :ok
    end

    test "handles oauth2_build_authorize_url, oauth2_get_token and oauth2_refresh_token" do
      defmodule OAuth2PluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "oauth2_plugin",
            display_name: %{"en_US" => "OAuth2 Plugin"},
            description: %{"en_US" => "Plugin with oauth2 callbacks"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [
              %{
                name: "google_drive",
                oauth2: true,
                oauth2_build_authorize_url: fn %{redirect_uri: redirect_uri, state: state} ->
                  {:ok, %{"url" => "#{redirect_uri}?state=#{state}"}}
                end,
                oauth2_get_token: fn %{code: code} ->
                  {:ok, %{"parameters_patch" => %{"access_token" => "token_#{code}"}}}
                end,
                oauth2_refresh_token: fn _args ->
                  {:ok, %{"parameters_patch" => %{"access_token" => "token_refreshed"}}}
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
             plugin_module: OAuth2PluginModule,
             test_mode?: true,
             task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
           ]}
        )

      accept_connect(client)
      assert_join("debug_plugin:oauth2_plugin", %{}, :ok)

      assert_push("debug_plugin:oauth2_plugin", "register_plugin", _plugin, ref)
      reply(client, ref, :ok)

      push(client, "debug_plugin:oauth2_plugin", "oauth2_build_authorize_url", %{
        "request_id" => "oauth_req_1",
        "credential_name" => "google_drive",
        "redirect_uri" => "https://hub.example.com/callback",
        "state" => "state_123"
      })

      assert_push(
        "debug_plugin:oauth2_plugin",
        "oauth2_build_authorize_url_response",
        %{
          "request_id" => "oauth_req_1",
          "data" => %{"url" => "https://hub.example.com/callback?state=state_123"}
        },
        _
      )

      push(client, "debug_plugin:oauth2_plugin", "oauth2_get_token", %{
        "request_id" => "oauth_req_2",
        "credential_name" => "google_drive",
        "code" => "abc123"
      })

      assert_push(
        "debug_plugin:oauth2_plugin",
        "oauth2_get_token_response",
        %{
          "request_id" => "oauth_req_2",
          "data" => %{"parameters_patch" => %{"access_token" => "token_abc123"}}
        },
        _
      )

      push(client, "debug_plugin:oauth2_plugin", "oauth2_refresh_token", %{
        "request_id" => "oauth_req_3",
        "credential_name" => "google_drive",
        "credential" => %{"refresh_token" => "rt_1"}
      })

      assert_push(
        "debug_plugin:oauth2_plugin",
        "oauth2_refresh_token_response",
        %{
          "request_id" => "oauth_req_3",
          "data" => %{"parameters_patch" => %{"access_token" => "token_refreshed"}}
        },
        _
      )
    end

    test "handles oauth2 callback errors when callback not found" do
      defmodule OAuth2NoCallbackPluginModule do
        def definition do
          PluginDefinition.new(%{
            lang: :elixir,
            name: "oauth2_no_callback_plugin",
            display_name: %{"en_US" => "OAuth2 No Callback Plugin"},
            description: %{"en_US" => "Plugin without oauth2 callback"},
            icon: "🔐",
            author: "Test",
            email: "test@example.com",
            version: "1.0.0",
            credentials: [%{name: "google_drive", oauth2: true}],
            tools: []
          })
        end
      end

      ExUnit.CaptureLog.capture_log(fn ->
        client =
          start_supervised!(
            {HubClient,
             [
               plugin_module: OAuth2NoCallbackPluginModule,
               test_mode?: true,
               task_supervisor: AtomemoPluginSdk.TestTaskSupervisor
             ]}
          )

        accept_connect(client)
        assert_join("debug_plugin:oauth2_no_callback_plugin", %{}, :ok)

        assert_push("debug_plugin:oauth2_no_callback_plugin", "register_plugin", _plugin, ref)
        reply(client, ref, :ok)

        push(client, "debug_plugin:oauth2_no_callback_plugin", "oauth2_get_token", %{
          "request_id" => "oauth_req_error",
          "credential_name" => "google_drive",
          "code" => "abc123"
        })

        assert_push(
          "debug_plugin:oauth2_no_callback_plugin",
          "oauth2_get_token_error",
          %{
            "request_id" => "oauth_req_error",
            "error" => %{
              "code" => "sdk:invalid_callback",
              "message" => "oauth2_get_token must be a function with arity 1"
            }
          },
          _
        )
      end)
    end
  end
end
