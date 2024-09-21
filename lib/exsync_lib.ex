require Logger

defmodule ExSyncLib do
  defdelegate register_group_leader, to: ExSyncLib.Logger.Server

  defdelegate compile_directory(src_dir, env), to: ExSyncLib.Utils

  defdelegate nl(nodes, module), to: ExSyncLib.Utils
  defdelegate nl(nodes, module, file, binary), to: ExSyncLib.Utils
end
