defmodule ExSyncLib.Logger do
  alias ExSyncLib.Logger.Server

  defdelegate debug(message), to: Server
  defdelegate info(message), to: Server
  defdelegate warn(message), to: Server
  defdelegate error(message), to: Server
end
