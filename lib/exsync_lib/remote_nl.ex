defmodule ExSyncLib.RemoteNl do
  def reload_unload(mod_infos, modules_to_remove)
      when is_list(mod_infos) and is_list(modules_to_remove) do
    for {module, file_path, binary} <- mod_infos do
      :code.load_binary(module, file_path, binary)
    end

    for module <- modules_to_remove do
      :code.purge(module)
      :code.delete(module)
    end
  end
end
