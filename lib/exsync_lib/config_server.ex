defmodule ExSyncLib.ConfigServer do
  use GenServer

  def start_link(opts \\ [], name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    state = opts
    {:ok, state}
  end
end
