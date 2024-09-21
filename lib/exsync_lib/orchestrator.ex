defmodule ExSyncLib.Orchestrator do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) when is_list(opts) do
    mixfile_path = Keyword.fetch!(opts, :mixfile_path)
    mix_target = Keyword.fetch!(opts, :mix_target)
    build_path = Keyword.fetch!(opts, :build_path)
    node = Keyword.fetch!(opts, :node)

    other_children = Keyword.get(opts, :other_children, [])

    IO.inspect(build_path, label: "build_path")
    {:ok, src_dirs, beam_dirs} =  ExSyncLib.ProjectAnalyzerServer.run(mixfile_path, build_path)

    mixfile_dir = Path.dirname(mixfile_path)
    src_extensions = ExSyncLib.Config.src_extensions()

    children =
      [
        src_monitor(mixfile_dir, mix_target, build_path, src_dirs, src_extensions),
        beam_monitor(node, beam_dirs),
        other_children
      ]
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp src_monitor(mixfile_dir, mix_target, build_path, src_dirs, src_extensions) do
    if src_dirs == [] || src_extensions == [] do
      []
    else
      [
        {ExSyncLib.SrcMonitor,
         [
           mixfile_dir: mixfile_dir,
           build_path: build_path,
           src_dirs: src_dirs,
           src_extensions: src_extensions,
           mix_target: mix_target
         ]}
      ]
    end
  end

  defp beam_monitor(_node, []), do: []

  defp beam_monitor(node, beam_dirs) do
    [{ExSyncLib.BeamMonitor, [beam_dirs: beam_dirs, node: node]}]
  end
end
