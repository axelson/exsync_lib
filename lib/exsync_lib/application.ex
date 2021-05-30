require Logger

defmodule ExSyncLib.Application do
  def start(_, _) do
    case Mix.env() do
      :dev ->
        start_supervisor()

      _ ->
        Logger.error("ExSyncLib NOT started. Only `:dev` environment is supported.")
        {:ok, self()}
    end
  end

  def start() do
    Application.ensure_all_started(:exsync_lib)
  end

  def start_supervisor do
    children =
      [
        ExSyncLib.Logger.Server,
        maybe_include_src_monitor(),
        ExSyncLib.BeamMonitor
      ]
      |> List.flatten()

    opts = [
      strategy: :one_for_one,
      max_restarts: 2,
      max_seconds: 3,
      name: ExSyncLib.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def maybe_include_src_monitor do
    if ExSyncLib.Config.src_monitor_enabled() do
      [ExSyncLib.SrcMonitor]
    else
      []
    end
  end

  defdelegate register_group_leader, to: ExSyncLib.Logger.Server
end
