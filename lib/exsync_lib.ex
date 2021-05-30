require Logger

defmodule ExSyncLib do
  defdelegate register_group_leader, to: ExSyncLib.Logger.Server
end
