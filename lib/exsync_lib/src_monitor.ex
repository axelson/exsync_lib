defmodule ExSyncLib.SrcMonitor do
  use GenServer
  require Logger

  @throttle_timeout_ms 100

  defmodule State do
    defstruct [
      :throttle_timer,
      :file_events,
      :watcher_pid,
      :src_extensions,
      :build_path,
      :mixfile_dir,
      :mix_target
    ]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    src_dirs = Keyword.fetch!(opts, :src_dirs)
    src_extensions = Keyword.get(opts, :src_extensions, ExSyncLib.Config.src_extensions())
    mixfile_dir = Keyword.get(opts, :mixfile_dir)
    mix_target = Keyword.get(opts, :mix_target)
    build_path = Keyword.get(opts, :build_path)

    Logger.debug("ExSyncLib source dirs: #{inspect(src_dirs)}")

    {:ok, watcher_pid} =
      FileSystem.start_link(
        dirs: src_dirs,
        backend: Application.get_env(:file_system, :backend)
      )

    FileSystem.subscribe(watcher_pid)
    Logger.debug("ExSyncLib source monitor started.")

    state = %State{
      build_path: build_path,
      watcher_pid: watcher_pid,
      src_extensions: src_extensions,
      mixfile_dir: mixfile_dir,
      mix_target: mix_target
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:file_event, watcher_pid, {path, events}}, %{watcher_pid: watcher_pid} = state) do
    %State{src_extensions: src_extensions} = state

    matching_extension? = Path.extname(path) in src_extensions

    # This varies based on editor and OS - when saving a file in neovim on linux,
    # events received are:
    #   :modified
    #   :modified, :closed
    #   :attribute
    # Rather than coding specific behaviors for each OS, look for the modified event in
    # isolation to trigger things.
    matching_event? = :modified in events

    state =
      if matching_extension? && matching_event? do
        maybe_compile_directory(state)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    Logger.debug("ExSyncLib src monitor stopped.")
    {:noreply, state}
  end

  def handle_info(:throttle_timer_complete, state) do
    compile_directory(state)

    state = %State{state | throttle_timer: nil}
    {:noreply, state}
  end

  defp maybe_compile_directory(%State{throttle_timer: nil} = state) do
    throttle_timer = Process.send_after(self(), :throttle_timer_complete, @throttle_timeout_ms)
    %State{state | throttle_timer: throttle_timer}
  end

  defp maybe_compile_directory(%State{} = state), do: state

  defp compile_directory(%State{} = state) do
    %State{build_path: build_path, mixfile_dir: mixfile_dir, mix_target: mix_target} = state
    IO.inspect(build_path, label: "build_path (src_monitor.ex:99)")

    env = [
      {"MIX_TARGET", mix_target},
      {"MIX_BUILD_ROOT", build_path}
    ]

    :telemetry.execute(
      [:exsync_lib, :compile, :start],
      %{},
      %{build_path: build_path}
    )

    ExSyncLib.Utils.compile_directory(mixfile_dir, env)
  end
end
