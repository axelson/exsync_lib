ExSyncLib
======

Yet another Elixir reloader.

## System Support

ExSyncLib deps on [FileSystem](https://github.com/falood/file_system)

## Usage

1. Create a new application:

```bash
mix new my_app
```

2. Add exsync_lib to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:exsync_lib, "~> 0.2", only: :dev},
  ]
end
```

Optionally add this snippet to your `.iex.exs` (in the root of your project) or your `~/.iex.exs`:
```
if Code.ensure_loaded?(ExSyncLib) && function_exported?(ExSyncLib, :register_group_leader, 0) do
  ExSyncLib.register_group_leader()
end
```

This will prevent the ExSyncLib logs from overwriting your IEx prompt.
Alternatively you can always just run `ExSyncLib.register_group_leader()` in your
IEx prompt.

## Usage for umbrella project

1. Create an umbrella project

```bash
mix new my_umbrella_app --umbrella
```

2. Add exsync_lib to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:exsync_lib, "~> 0.2", only: :dev},
  ]
end
```

3. start your umbrella project with `exsync_lib` task

```bash
iex -S mix exsync_lib
```

## Config

All configuration for this library is handled via the application environment.

`:addition_dirs` - Additional directories to monitor

For example, to monitor the `priv` directory, add this to your `config.exs`:

```elixir
config :exsync_lib, addition_dirs: ["/priv"]
```

`:extensions` - List of file extensions to watch for changes. Defaults to: `[".erl", ".hrl", ".ex", ".eex"]`

`:extra_extensions` - List of additional extensions to watch for changes (cannot be used with `:extensions`)

For example, to watch `.js` and `.css` files add this to your `config.exs`:

```elixir
config :exsync_lib, extra_extensions: [".js", ".css"]
```

`:logging_enabled` - Set to false to disable logging (default true)

`:reload_callback` - A callback [MFA](https://codereviewvideos.com/blog/what-is-mfa-in-elixir/) that is called when a set of files are done reloading. Can be used to implement your own special handling to react to file reloads.

`:reload_timeout` - Amount of time to wait in milliseconds before triggering the `:reload_callback`. Defaults to 150ms.

For example, to call `MyApp.MyModule.handle_reload()` add this to your `config.exs`:

```elixir
config :exsync_lib,
  reload_timeout: 75,
  reload_callback: {MyApp.MyModule, :handle_reload, []}
```
