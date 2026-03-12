## OAuth2 Credential 教程（面向插件开发者）

本文面向 **Atomemo 插件开发者**，讲解在插件中如何 **定义和实现 OAuth2 类型的 credential**，并和 hub 的自动刷新机制配合工作。  
所有示例都基于当前的 `demo_plugin_ex` 实现（`DemoPluginEx` / `DemoPluginEx.Credentials.GoogleDrive`），不是伪接口。

---

### 1. 整体概念和数据流

在现有实现里，一个 OAuth2 credential 拆成两部分：

- **在插件定义里（`PluginDefinition`）声明 schema 和回调**
  - 在 `credentials` 数组里：
    - 定义 credential 的 **name / 文案 / icon**
    - 标记 `oauth2: true`
    - 定义 **parameters** 字段（包含 `client_id/client_secret/access_token/refresh_token/expires_at` 等）
    - 绑定一组回调函数：
      - `authenticate`
      - `oauth2_build_authorize_url`
      - `oauth2_get_token`
      - `oauth2_refresh_token`

- **在 credential 模块里实现这些回调**
  - 例如 `DemoPluginEx.Credentials.GoogleDrive`：
    - `build_authorize_url/1`：构造第三方 OAuth2 授权 URL
    - `get_token/1`：用 `code` 换取 `access_token` + `refresh_token`
    - `refresh_token/1`：用 `refresh_token` 刷新 `access_token`
    - `authenticate/1`：把 credential 转成真正调用三方 API 需要的 headers/config

**存储形态**：

- hub 那边保存的是一条 credential 记录，里面有：
  - `name`（如 `"google_drive"`）
  - `parameters`（一个 map，对应你声明的 `parameters` 列表里的字段）
- 每次 OAuth2 回调成功后，你返回一个 `parameters_patch`，hub 用它去更新 `parameters`。

---

### 2. 在 PluginDefinition 里声明一个 OAuth2 credential

schema 和所有回调入口都定义在 `PluginDefinition` 里，而不是某个 behaviour 的 `fields/0`。  
以 `demo_plugin_ex` 为例（节选）：

```elixir
defmodule DemoPluginEx do
  alias AtomemoPluginSdk.PluginDefinition

  def definition do
    version = Application.spec(:demo_plugin_ex, :vsn) |> to_string()

    PluginDefinition.new(%{
      lang: :elixir,
      name: "demo_plugin_ex",
      display_name: %{"en_US" => "Demo Plugin Ex"},
      description: %{"en_US" => "Demo plugin (Elixir)"},
      icon: "👋",
      author: "davidchen",
      email: "davidchen@example.com",
      version: version,
      credentials: [
        %{
          name: "api_key",
          # ... 省略 ...
        },
        %{
          name: "google_drive",
          display_name: %{"en_US" => "Google Drive"},
          description: %{"en_US" => "OAuth2 credentials for Google Drive API"},
          icon: "🗂️",
          oauth2: true,
          parameters: [
            %{
              type: "string",
              name: "client_id",
              display_name: %{"en_US" => "Client ID"},
              required: true
            },
            %{
              type: "encrypted_string",
              name: "client_secret",
              display_name: %{"en_US" => "Client Secret"},
              required: true
            },
            %{
              type: "encrypted_string",
              name: "access_token",
              display_name: %{"en_US" => "Access Token"}
            },
            %{
              type: "encrypted_string",
              name: "refresh_token",
              display_name: %{"en_US" => "Refresh Token"}
            },
            %{
              type: "integer",
              name: "expires_at",
              display_name: %{"en_US" => "Expires At"}
            }
          ],
          authenticate: &DemoPluginEx.Credentials.GoogleDrive.authenticate/1,
          oauth2_build_authorize_url: &DemoPluginEx.Credentials.GoogleDrive.build_authorize_url/1,
          oauth2_get_token: &DemoPluginEx.Credentials.GoogleDrive.get_token/1,
          oauth2_refresh_token: &DemoPluginEx.Credentials.GoogleDrive.refresh_token/1
        }
      ],
      tools: [
        # ...
      ],
      models: [
        # ...
      ]
    })
  end
end
```

**要点：**

- **`oauth2: true`**：这条 credential 按 OAuth2 流程处理。
- **`parameters`**：
  - `client_id` / `client_secret`：静态配置，用户/管理员在创建 credential 时填。
  - `access_token` / `refresh_token` / `expires_at`：由 OAuth2 回调写入（`parameters_patch`），不需要用户手填。
- 回调入口：
  - `authenticate/1`
  - `oauth2_build_authorize_url/1`
  - `oauth2_get_token/1`
  - `oauth2_refresh_token/1`

**注意**：`expires_at` 是一个特殊的字段，Hub 会根据这个字段计划服务端的定期更新 access token 。如果没有这个字段，Hub 就不会触发自动刷新。

**你要做的新 credential 定义**，基本就是在 `credentials` 里再加一条类似的 map，然后换成你自己的模块和字段名。

---

### 3. Credential 回调模块：授权 URL / 换 token / 刷新 / authenticate

以 `DemoPluginEx.Credentials.GoogleDrive` 为完整示例：

```elixir
defmodule DemoPluginEx.Credentials.GoogleDrive do
  @moduledoc """
  Google Drive OAuth2 credential callbacks.
  """

  @authorization_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @token_endpoint "https://oauth2.googleapis.com/token"
  @default_scopes ["https://www.googleapis.com/auth/drive.readonly"]

  @doc """
  Build full Google OAuth2 authorization URL.
  """
  def build_authorize_url(args) when is_map(args) do
    credential = args.credential
    redirect_uri = args.redirect_uri
    state = args.state
    client_id = credential["client_id"]

    with true <- is_binary(client_id) and client_id != "",
         true <- is_binary(redirect_uri) and redirect_uri != "",
         true <- is_binary(state) and state != "" do
      params = %{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: Enum.join(@default_scopes, " "),
        state: state,
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: "true"
      }

      {:ok, %{"url" => "#{@authorization_endpoint}?#{URI.encode_query(params)}"}}
    else
      _ ->
        {:error,
         %{"code" => "invalid_args", "message" => "client_id/redirect_uri/state is required"}}
    end
  end

  @doc """
  Exchange authorization code for tokens.
  """
  def get_token(args) when is_map(args) do
    credential = args.credential
    code = args.code
    redirect_uri = args.redirect_uri
    client_id = credential["client_id"]
    client_secret = credential["client_secret"]

    with true <- is_binary(client_id) and client_id != "",
         true <- is_binary(client_secret) and client_secret != "",
         true <- is_binary(code) and code != "",
         true <- is_binary(redirect_uri) and redirect_uri != "" do
      body = %{
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri,
        grant_type: "authorization_code"
      }

      req_new()
      |> Req.post(url: @token_endpoint, form: body)
      |> case do
        {:ok, %{status: 200, body: response}} ->
          parameters_patch = %{
            "access_token" => response["access_token"],
            "refresh_token" => response["refresh_token"]
          }

          parameters_patch =
            if expires_in = response["expires_in"] do
              Map.put(parameters_patch, "expires_at", System.system_time(:second) + expires_in)
            else
              parameters_patch
            end

          {:ok, %{"parameters_patch" => parameters_patch}}

        {:ok, %{body: %{"error" => error, "error_description" => description}}} ->
          {:error, %{"code" => error, "message" => description}}

        {:error, reason} ->
          {:error, %{"code" => "request_failed", "message" => inspect(reason)}}
      end
    else
      _ ->
        {:error,
         %{
           "code" => "invalid_args",
           "message" => "client credentials/code/redirect_uri is required"
         }}
    end
  end

  @doc """
  Refresh access token from refresh token.
  """
  def refresh_token(args) when is_map(args) do
    credential = args.credential
    client_id = credential["client_id"]
    client_secret = credential["client_secret"]
    refresh_token = credential["refresh_token"]

    with true <- is_binary(client_id) and client_id != "",
         true <- is_binary(client_secret) and client_secret != "",
         true <- is_binary(refresh_token) and refresh_token != "" do
      body = %{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      }

      req_new()
      |> Req.post(url: @token_endpoint, form: body)
      |> case do
        {:ok, %{status: 200, body: response}} ->
          parameters_patch = %{"access_token" => response["access_token"]}

          parameters_patch =
            if expires_in = response["expires_in"] do
              Map.put(parameters_patch, "expires_at", System.system_time(:second) + expires_in)
            else
              parameters_patch
            end

          {:ok, %{"parameters_patch" => parameters_patch}}

        {:ok, %{body: %{"error" => error, "error_description" => description}}} ->
          {:error, %{"code" => error, "message" => description}}

        {:error, reason} ->
          {:error, %{"code" => "request_failed", "message" => inspect(reason)}}
      end
    else
      _ ->
        {:error,
         %{
           "code" => "invalid_args",
           "message" => "client credentials/refresh_token is required"
         }}
    end
  end

  @doc """
  For credential_auth_spec in tool invocation flow.
  """
  def authenticate(args) when is_map(args) do
    credential = args.credential
    access_token = credential["access_token"]

    if is_binary(access_token) and access_token != "" do
      {:ok,
       %{
         "adapter" => "google_drive",
         "headers" => %{
           "authorization" => "Bearer #{access_token}"
         }
       }}
    else
      {:error, "access_token is required"}
    end
  end

  defp req_new do
    Req.new(finch: FinchProxy)
  end
end
```

**约定：**

- hub 调用这些回调时，会把 **已解密后的 credential 参数 map** 塞进 `args.credential`。
- `get_token/1` / `refresh_token/1` 返回 `{:ok, %{"parameters_patch" => %{...}}}`，hub 用这个 patch 更新这条 credential 的 `parameters`。
- 失败时统一返回 `{:error, %{"code" => ..., "message" => ...}}`，方便 hub 透传错误信息。
- 所有 HTTP 调用用的是 `Req`，遵守项目要求。

---

### 4. 授权 URL 流程：从 Atomemo 到第三方

这部分细节在 WebSocket 协议文档里有描述，这里只从插件视角总结：

1. 前端/调用方想给某条 credential 做 OAuth2 授权，发起类似的请求到 hub（具体见 `websocket_protocol.md`）；
2. hub 根据 credential 的 `name` 找到对应定义（例如 `"google_drive"`）；
3. hub 调用你在 `PluginDefinition` 里绑定的 `oauth2_build_authorize_url/1`，即 `DemoPluginEx.Credentials.GoogleDrive.build_authorize_url/1`；
4. 你返回一个 `{:ok, %{"url" => full_url}}`；
5. hub 把这个 URL 回传给前端，让用户在浏览器中完成 OAuth2 授权。

你这边要保证：

- 从 `args.credential` 里能拿到一个合法的 `client_id`；
- 正确使用 hub 提供的 `redirect_uri` / `state`；
- 按 provider 要求设置 `scope` / `access_type` / `prompt` 等。

---

### 5. 回调换 token：从 code 到 access_token/refresh_token

用户在第三方授权完成后，第三方重定向到 hub 管理的 `redirect_uri`，带上 `code` 和 `state`。  
hub 会按 WebSocket 协议把这些信息转成一次 `oauth2_get_token` 调用，最终落到你实现的 `get_token/1` 上。

`DemoPluginEx.Credentials.GoogleDrive.get_token/1` 的关键逻辑：

- 从 `args.credential` 读 `client_id/client_secret`；
- 从 `args` 读 `code` / `redirect_uri`；
- 用 `Req` 调 `@token_endpoint` 换 token；
- 从响应里读出 `access_token` / `refresh_token` / `expires_in`；
- 计算出 `expires_at`（当前时间 + `expires_in` 秒，单位秒的 unix time）；
- 返回：

```elixir
{:ok,
 %{
   "parameters_patch" => %{
     "access_token" => response["access_token"],
     "refresh_token" => response["refresh_token"],
     "expires_at" => System.system_time(:second) + expires_in
   }
 }}
```

hub 拿到这个 `parameters_patch` 后，会 patch 当前 credential 的 `parameters` 字段，后续你在 `authenticate/1` 或业务代码里看到的就是最新的 token。

---

### 6. 自动刷新流程：refresh_token -> 新 access_token

自动刷新这块在 hub 里由一个 job（比如 `RefreshCredentialTokenJob`）负责调度，大致逻辑是：

1. job 找出所有快过期或已过期的 OAuth2 credential；
2. 按 credential 对应的插件/定义，调用绑定的 `oauth2_refresh_token` 回调；
3. 也就是你实现的 `DemoPluginEx.Credentials.GoogleDrive.refresh_token/1`；
4. 你用 `refresh_token` 调 OAuth2 token endpoint 换新的 `access_token`；
5. 返回 `{:ok, %{"parameters_patch" => %{"access_token" => ..., "expires_at" => ...}}}`；
6. hub 用 patch 更新 credential。

在 Google Drive 示例里，如果响应里有 `expires_in` 就顺便更新 `expires_at`，否则只更新 `access_token`。  
如果某些 provider 在 refresh 时会返回新的 `refresh_token`，你可以同步把它加入 `parameters_patch`，hub 就会跟着更新。

---

### 7. 在工具调用中使用 OAuth2 credential

工具（tool）真正用到 credential 时，有两种常见模式：

1. **通过 `credential_auth_spec` 让 hub 注入 headers**：
   - 你在某个 tool 的定义里声明这个 tool 需要哪个 credential；
   - hub 在调用 tool 前，会先走一遍 `authenticate/1`；
   - 你在 `authenticate/1` 里返回一个结构，告诉调用方应该加哪些 header：

   ```elixir
   {:ok,
    %{
      "adapter" => "google_drive",
      "headers" => %{
        "authorization" => "Bearer #{access_token}"
      }
    }}
   ```

2. **直接读 credential 的 parameters**：
   - 工具里拿到 credential 对象（已解密）；
   - 直接从 `parameters["access_token"]` 里取值，自行用 `Req` 调三方。

对插件开发者来说，比较推荐第一种，逻辑集中在 `authenticate/1`，工具本身就不再直接操作 credential 字段。

---

### 8. 实现新 OAuth2 credential 的步骤小结

如果你要为另一个 provider（比如 Slack、Notion）实现 OAuth2 credential，大致步骤是：

1. **在 `PluginDefinition` 里新增一条 credential 定义**：
   - `name: "slack_oauth2"`（随便取，只要和你自己工具里的 `credential_name` 对上）
   - `oauth2: true`
   - `parameters` 至少包含：
     - `client_id`（string）
     - `client_secret`（encrypted_string）
     - `access_token`（encrypted_string）
     - `refresh_token`（encrypted_string，部分 provider 可选）
     - `expires_at`（integer 或你约定的其它形式）
   - 绑定四个回调到你自己的模块。

2. **实现 credential 模块**（`MyPlugin.Credentials.Slack` 等）：
   - 参考 `DemoPluginEx.Credentials.GoogleDrive`：
     - 写 `build_authorize_url/1`，用 provider 的 authorize endpoint + 你需要的 scope；
     - 写 `get_token/1`，调用 provider 的 token endpoint，用 `code` 换 token；
     - 写 `refresh_token/1`，用 `refresh_token` 换新 `access_token`；
     - 写 `authenticate/1`，输出业务方便直接使用的 headers/config；
   - 所有 HTTP 请求都用 `Req`。

3. **在工具定义里声明对 credential 的依赖**（如果需要 hub 自动注入）：
   - 参考现有 `get_credential` / 其它工具怎么接 credential。

4. **根据实际 provider 的文档作细节调整**：
   - redirect_uri 必须和 hub 那边配置的一致；
   - 某些 provider 不给 refresh_token 或只有第一次授权给；
   - 某些 provider 的过期时间字段叫别的名字；你可以自行映射成 `expires_at`。

做到这三块，你的 OAuth2 credential 在整个系统里就可以完整跑通：创建 -> 授权 -> 存储 -> 自动刷新 -> 工具调用。
