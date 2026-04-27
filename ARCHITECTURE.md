# Atomemo Plugin SDK (Elixir) 架构文档

## 1. 项目定位

这是一个插件侧 Elixir SDK：  
- 用 Ecto embedded schema 描述插件能力（凭证、工具、模型）。
- 用 Slipstream 连接 Atomemo Hub WebSocket，接收 Hub 事件并调用插件回调。
- 用 Req 处理文件相关 HTTP 访问。

关键文件：
- `lib/atomemo_plugin_sdk/plugin_definition.ex`
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `lib/atomemo_plugin_sdk/context/files.ex`

## 2. 顶层目录职责

- `lib/`：核心实现（定义、编解码、运行时、上下文、错误模型）。
- `test/`：ExUnit 测试，结构基本镜像 `lib/`。
- `test/support/`：测试辅助模块（test 环境额外编译）。
- `config/`：运行环境配置（`config.exs` + `test.exs`）。
- `docs/`：协议和凭证文档（WebSocket / OAuth2）。
- `.github/workflows/`：发版自动化（版本升级后发 Hex）。

关键文件：
- `mix.exs`
- `config/config.exs`
- `config/test.exs`
- `docs/websocket_protocol.md`
- `docs/credential_oauth2.md`
- `.github/workflows/release-on-version-bump.yml`

## 3. 代码结构（模块分层）

### 3.1 定义层（Definition Layer）

负责描述插件“声明式能力”，用于注册与校验。

- `AtomemoPluginSdk.PluginDefinition`
  - 插件根定义（`credentials` / `tools` / `models`）。
  - 文件：`lib/atomemo_plugin_sdk/plugin_definition.ex`
- `AtomemoPluginSdk.CredentialDefinition`
  - 凭证定义、OAuth2 元数据、认证回调（虚拟字段不序列化）。
  - 文件：`lib/atomemo_plugin_sdk/credential_definition.ex`
- `AtomemoPluginSdk.ToolDefinition`
  - 工具定义、`invoke` / `locator_list` / `resource_mapping` 回调入口。
  - 文件：`lib/atomemo_plugin_sdk/tool_definition.ex`
- `AtomemoPluginSdk.ModelDefinition`
  - 模型能力定义。
  - 文件：`lib/atomemo_plugin_sdk/model_definition.ex`

### 3.2 参数系统（Parameter System）

负责参数 schema 与 runtime value 的转换/校验。

- `AtomemoPluginSdk.ParameterDefinition`
  - 多态参数类型总入口（string/number/object/array/...）。
  - 文件：`lib/atomemo_plugin_sdk/parameter_definition.ex`
- `lib/atomemo_plugin_sdk/parameter_definition/*.ex`
  - 具体参数类型实现（`file_ref`、`llm_config`、`resource_*` 等）。
- `AtomemoPluginSdk.ParameterCodec`
  - 编解码协议定义，具体实现位于 `parameter_codec/*.ex`。
  - 文件：`lib/atomemo_plugin_sdk/parameter_codec.ex`

### 3.3 运行时层（Socket Runtime）

负责与 Hub 通信、事件路由、回调调度、错误回传。

- `AtomemoPluginSdk.SocketRuntime`
  - 启动 supervision children（`Task.Supervisor` + `HubClient`）。
  - 文件：`lib/atomemo_plugin_sdk/socket_runtime.ex`
- `AtomemoPluginSdk.SocketRuntime.HubClient`
  - WebSocket 客户端与事件核心路由。
  - 文件：`lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `AtomemoPluginSdk.SocketRuntime.CallbackRunner`
  - 回调执行、超时、错误归一化。
  - 文件：`lib/atomemo_plugin_sdk/socket_runtime/callback_runner.ex`
- `AtomemoPluginSdk.SocketRuntime.HubCaller`
  - 工具内同步调用 Hub 的 API 封装（`hub_call:*`）。
  - 文件：`lib/atomemo_plugin_sdk/socket_runtime/hub_caller.ex`
- `AtomemoPluginSdk.SocketRuntimeConfig`
  - 从环境变量构建运行配置并校验。
  - 文件：`lib/atomemo_plugin_sdk/socket_runtime_config.ex`

### 3.4 上下文与传输层（Context & Transport）

- `AtomemoPluginSdk.Context`
  - 请求上下文（`organization_id` / `request_id` / `__hub_client__`）。
  - 文件：`lib/atomemo_plugin_sdk/context.ex`
- `AtomemoPluginSdk.ParameterHydrator`
  - 将 Hub payload 还原为 typed struct（例如 `FileRef`、`LLMConfig`）。
  - 文件：`lib/atomemo_plugin_sdk/parameter_hydrator.ex`
- `AtomemoPluginSdk.Context.Files`
  - 文件下载/上传的 HTTP 操作（Req）。
  - 文件：`lib/atomemo_plugin_sdk/context/files.ex`
- `AtomemoPluginSdk.Context.LLM`
  - LLM 相关上下文能力。
  - 文件：`lib/atomemo_plugin_sdk/context/llm.ex`

### 3.5 错误与通用模型

- `AtomemoPluginSdk.SdkError`
- `AtomemoPluginSdk.TransientError`
- `AtomemoPluginSdk.ParameterError`
- `AtomemoPluginSdk.JSONValue`
- `AtomemoPluginSdk.I18nEntry`

关键文件：
- `lib/atomemo_plugin_sdk/sdk_error.ex`
- `lib/atomemo_plugin_sdk/transient_error.ex`
- `lib/atomemo_plugin_sdk/parameter_error.ex`
- `lib/atomemo_plugin_sdk/json_value.ex`
- `lib/atomemo_plugin_sdk/i18n_entry.ex`

## 4. 运行时架构与依赖方向

```text
Plugin Module (宿主实现 definition/0)
  -> PluginDefinition / ToolDefinition / CredentialDefinition
  -> SocketRuntime.start_link(...)
     -> Task.Supervisor
     -> HubClient (Slipstream)
        -> handle_message(event)
        -> ParameterHydrator
        -> CallbackRunner.dispatch(callback)
        -> push *_response / *_error 回 Hub
```

依赖方向：
- 定义层依赖参数层（`CredentialDefinition`、`ToolDefinition` 使用 `ParameterDefinition` 宏）。
- 运行时依赖定义层（按名称查找 tool/credential）。
- 运行时依赖传输层（`ParameterHydrator` + `Context`）与错误层（`SdkError`/`TransientError`）。

关键文件：
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `lib/atomemo_plugin_sdk/tool_definition.ex`
- `lib/atomemo_plugin_sdk/credential_definition.ex`
- `lib/atomemo_plugin_sdk/parameter_hydrator.ex`

## 5. 核心流程

### 5.1 连接与注册流程

1. `HubClient.init/1` 读取 `SocketRuntimeConfig.load_from_env/0`。  
2. 调用插件模块 `definition/0` 取得 `PluginDefinition`。  
3. 建立 WebSocket 连接：  
   - debug: `/debug_socket/websocket`
   - release: `/release_socket/websocket`
4. join topic 后：
   - debug 模式主动 `register_plugin`
   - release 模式依赖 join 成功即完成 claim

关键文件：
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `lib/atomemo_plugin_sdk/socket_runtime_config.ex`
- `docs/websocket_protocol.md`

### 5.2 工具调用流程（`invoke_tool`）

1. `HubClient.handle_message/4` 收到 `invoke_tool`。
2. 校验 `request_id`、`tool_name`，按名称查找 `ToolDefinition`。
3. `ParameterHydrator.call/1` 解析 `parameters` 和 `credentials`。
4. 构造 `Context`，交给 `CallbackRunner.dispatch/3` 执行 `tool.invoke`。
5. 回传 `invoke_tool_response` 或 `invoke_tool_error`。

关键文件：
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `lib/atomemo_plugin_sdk/socket_runtime/callback_runner.ex`
- `lib/atomemo_plugin_sdk/parameter_hydrator.ex`

### 5.3 凭证认证与 OAuth2 流程

支持事件：
- `credential_auth_spec`
- `oauth2_build_authorize_url`
- `oauth2_get_token`
- `oauth2_refresh_token`

统一模式：
1. 校验 `credential_name`，查找 `CredentialDefinition`。
2. 解析 credential payload。
3. 调用对应回调（`authenticate` / `oauth2_*`）。
4. 回传 `*_response` 或 `*_error`。

关键文件：
- `lib/atomemo_plugin_sdk/credential_definition.ex`
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `docs/credential_oauth2.md`

### 5.4 资源流程（locator / mapping）

支持：
- `locator_list`：调用 `tool.locator_list[method]`
- `resource_mapping`：调用 `tool.resource_mapping[method]`

关键文件：
- `lib/atomemo_plugin_sdk/tool_definition.ex`
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`

### 5.5 Hub 同步调用流程（`hub_call:*`）

1. 业务侧通过 `HubCaller` 发起 `{:hub_call, event, request_id, payload, from}`。
2. `HubClient` push `hub_call:<event>` 到当前 topic。
3. 通过 `pending_hub_calls` 追踪 request_id，收到 `hub_call_response`/`hub_call_error` 后回发给调用方进程。

关键文件：
- `lib/atomemo_plugin_sdk/socket_runtime/hub_caller.ex`
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`

## 6. 应用启动模型

- `AtomemoPluginSdk.Application` 在 test 环境仅启动 `AtomemoPluginSdk.TestTaskSupervisor`。
- 非 test 环境默认不自动启动 `SocketRuntime`，由宿主应用自行纳入监督树。

关键文件：
- `lib/atomemo_plugin_sdk/application.ex`

## 7. 构建、测试、文档、发布

### 7.1 构建与质量门禁

- `mix check`：
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix test`

关键文件：
- `mix.exs`

### 7.2 测试分布

- 参数与定义：`test/atomemo_plugin_sdk/*_test.exs`
- 运行时：`test/atomemo_plugin_sdk/socket_runtime/*_test.exs`
- 测试辅助：`test/support/helpers.ex`

### 7.3 文档与发布

- 文档：`ex_doc`，`main: "readme"`。
- 发布：GitHub Actions 对比 Hex 最新版本，仅在 `version` 升级时执行 `mix hex.publish` 并打 tag。

关键文件：
- `mix.exs`
- `.github/workflows/release-on-version-bump.yml`

## 8. 外部依赖与集成点

- `slipstream`：WebSocket 通道通信。
- `req`：HTTP 文件传输。
- `ecto` + `polymorphic_embed`：定义层与参数层。
- OTP `:json`（通过 `JSON` 模块）用于连接与 payload 解析。

关键文件：
- `mix.exs`
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `lib/atomemo_plugin_sdk/context/files.ex`

## 9. 扩展指南（按代码机制）

### 9.1 新增参数类型

至少需要同时改：
1. `ParameterDefinition` 类型注册。
2. 对应 `parameter_definition/<type>.ex`。
3. 对应 `parameter_codec/<type>.ex`。
4. 如涉及 runtime typed payload，再更新 `ParameterHydrator`。

关键文件：
- `lib/atomemo_plugin_sdk/parameter_definition.ex`
- `lib/atomemo_plugin_sdk/parameter_codec.ex`
- `lib/atomemo_plugin_sdk/parameter_hydrator.ex`

### 9.2 新增 Hub 事件

1. 在 `HubClient.handle_message/4` 增加事件分支。
2. 实现参数提取、对象查找、回调调度与回包事件。
3. 对应补测试（事件成功/失败/超时路径）。

关键文件：
- `lib/atomemo_plugin_sdk/socket_runtime/hub_client.ex`
- `test/atomemo_plugin_sdk/socket_runtime/hub_client_test.exs`

## 10. 当前可见限制（来自代码现状）

- `lib/atomemo_plugin_sdk.ex` 仍是占位模块（`hello/0`）。
- `mix.exs` 的 `licenses` 为空。
- 当前工作流偏发版导向，未见常规 PR/push 测试 CI。
- SDK 不自动在 prod 启动 runtime，接入方需自行挂监督树。

关键文件：
- `lib/atomemo_plugin_sdk.ex`
- `mix.exs`
- `.github/workflows/release-on-version-bump.yml`
- `lib/atomemo_plugin_sdk/application.ex`
