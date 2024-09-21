defmodule ExSyncLib.Application do
  require Logger

  def start(_type, _args) do
    beam_notify_options = [
      name: ExSyncLib.Config.beam_notify_name(),
      dispatcher: &ExSyncLib.ProjectAnalyzerServer.handle_beam_notify/2
    ]

    children = [
      ExSyncLib.ProjectAnalyzerServer,
      {BEAMNotify, beam_notify_options},
    ]

    opts = [
      strategy: :one_for_one,
      max_restarts: 2,
      max_seconds: 3,
      name: ExSyncLib.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
