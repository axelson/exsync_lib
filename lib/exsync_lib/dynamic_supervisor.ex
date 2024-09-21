defmodule ExSyncLib.DynamicSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    {name, opts} = Keyword.pop_first(opts, :name, nil)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(supervisor, mixfile_path, node, build_path, mix_target, other_children) do
    spec =
      {ExSyncLib.Orchestrator,
       [
         mixfile_path: mixfile_path,
         build_path: build_path,
         mix_target: mix_target,
         node: node,
         other_children: other_children,
       ]}

    bootstrap_node(node)

    DynamicSupervisor.start_child(supervisor, spec)
  end

  # We need a small amount of our code to run on the remote node to receive updates
  defp bootstrap_node(node) do
    ExSyncLib.nl([node], ExSyncLib.RemoteNl)
  end
end
