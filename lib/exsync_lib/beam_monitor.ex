defmodule ExSyncLib.BeamMonitor do
  use GenServer
  require Logger

  @throttle_timeout_ms 100

  defmodule State do
    @enforce_keys [
      :finished_reloading_timer,
      :throttle_timer,
      :watcher_pid,
      :unload_set,
      :reload_set,
      :node
    ]
    defstruct [
      :finished_reloading_timer,
      :throttle_timer,
      :watcher_pid,
      :unload_set,
      :reload_set,
      :node
    ]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    # {:ok, watcher_pid} = FileSystem.start_link(dirs: ExSyncLib.Config.beam_dirs())
    beam_dirs = Keyword.fetch!(opts, :beam_dirs)
    node = Keyword.fetch!(opts, :node)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: beam_dirs)
    FileSystem.subscribe(watcher_pid)
    Logger.debug("ExSyncLib beam monitor started with dirs: #{inspect(beam_dirs)}")

    state = %State{
      finished_reloading_timer: false,
      throttle_timer: nil,
      watcher_pid: watcher_pid,
      unload_set: MapSet.new(),
      reload_set: MapSet.new(),
      node: node
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    %State{finished_reloading_timer: finished_reloading_timer} = state

    action = action(Path.extname(path), path, events)

    if finished_reloading_timer && action != :nothing do
      Process.cancel_timer(finished_reloading_timer)
    end

    state =
      track_module_change(action, path, state)
      # TODO: Is this correct?
      |> maybe_update_throttle_timer()

    reload_timeout = ExSyncLib.Config.reload_timeout()

    finished_reloading_timer =
      if action == :nothing do
        finished_reloading_timer
      else
        Process.send_after(self(), :reload_complete, reload_timeout)
      end

    {:noreply, %{state | finished_reloading_timer: finished_reloading_timer}}
  end

  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    Logger.debug("beam monitor stopped")
    {:noreply, state}
  end

  def handle_info(:throttle_timer_complete, state) do
    state = reload_and_unload_modules(state)
    state = %State{state | throttle_timer: nil}

    {:noreply, state}
  end

  def handle_info(:reload_complete, state) do
    Logger.info("reload complete #{inspect(self())}")

    :telemetry.execute(
      [:exsync_lib, :reload, :finish],
      %{},
      %{}
    )

    if callback = ExSyncLib.Config.reload_callback() do
      {mod, fun, args} = callback
      Task.start(mod, fun, args)
    end

    {:noreply, state}
  end

  defp action(".beam", path, events) do
    case {:created in events, :removed in events, :modified in events, File.exists?(path)} do
      # update
      {_, _, true, true} -> :reload_module
      # temp file
      {true, true, _, false} -> :nothing
      # remove
      {_, true, _, false} -> :unload_module
      # create and other
      _ -> :nothing
    end
  end

  defp action(_extname, _path, _events), do: :nothing

  defp track_module_change(:nothing, _module, state), do: state

  defp track_module_change(:reload_module, module, state) do
    %State{reload_set: reload_set, unload_set: unload_set} = state

    %State{
      state
      | reload_set: MapSet.put(reload_set, module),
        unload_set: MapSet.delete(unload_set, module)
    }
  end

  defp track_module_change(:unload_module, module, state) do
    %State{reload_set: reload_set, unload_set: unload_set} = state

    %State{
      state
      | reload_set: MapSet.delete(reload_set, module),
        unload_set: MapSet.put(unload_set, module)
    }
  end

  defp maybe_update_throttle_timer(%State{throttle_timer: nil} = state) do
    %State{reload_set: reload_set, unload_set: unload_set} = state

    if Enum.empty?(reload_set) && Enum.empty?(unload_set) do
      state
    else
      # Logger.debug("BeamMonitor Start throttle timer")
      throttle_timer = Process.send_after(self(), :throttle_timer_complete, @throttle_timeout_ms)
      %State{state | throttle_timer: throttle_timer}
    end
  end

  defp maybe_update_throttle_timer(state), do: state

  defp reload_and_unload_modules(%State{} = state) do
    %State{reload_set: reload_set, unload_set: unload_set, node: node} = state

    # Logger.debug("reload: #{inspect(MapSet.to_list(reload_set))}")
    # Logger.debug("unload: #{inspect(MapSet.to_list(unload_set))}")

    ExSyncLib.Utils.reload_multi(node, MapSet.to_list(reload_set), MapSet.to_list(unload_set))

    %State{state | reload_set: MapSet.new(), unload_set: MapSet.new()}
  end
end
