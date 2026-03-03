import Config

config :logger, level: :warning

# Let the AtomemoPluginSdk application know we're in the :test environment
config :atomemo_plugin_sdk, :config_env, :test
