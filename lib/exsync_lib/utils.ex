defmodule ExSyncLib.Utils do
  require Logger

  def compile_directory(src_dir, env) do
    Logger.info("running mix compile! from: #{inspect(src_dir)}")

    System.cmd("mix", ["compile"],
      cd: src_dir,
      stderr_to_stdout: true,
      env: env
    )
    |> log_compile_cmd_output()
  end

  def unload(module) when is_atom(module) do
    Logger.debug("unload module #{inspect(module)}")
    module |> :code.purge()
    module |> :code.delete()
  end

  def unload(beam_path) do
    beam_path |> Path.basename(".beam") |> String.to_atom() |> unload
  end

  def reload_multi(node, beam_paths, modules_to_remove) do
    mod_infos =
      for beam_path <- beam_paths do
        file_path = to_charlist(beam_path)
        binary = File.read!(file_path)
        module = beam_path |> Path.basename(".beam") |> String.to_atom()
        {module, file_path, binary}
      end

    nl_multi([node], mod_infos, modules_to_remove)
  end

  def reload(node, beam_path) do
    Logger.debug("reload module #{Path.basename(beam_path, ".beam")}")
    file_path = to_charlist(beam_path)
    binary = File.read!(file_path)
    module = beam_path |> Path.basename(".beam") |> String.to_atom()

    nl([node], module, file_path, binary)
  end

  defp log_compile_cmd_output({output, status} = result) when is_binary(output) and status > 0 do
    Logger.error(["error while compiling\n", output])
    result
  end

  defp log_compile_cmd_output({"", _status} = result) do
    result
  end

  defp log_compile_cmd_output({output, _status} = result) when is_binary(output) do
    message = ["compiling\n", output]

    if String.contains?(output, "warning:") do
      Logger.warn(message)
    else
      Logger.debug(message)
    end

    result
  end

  def nl_multi(nodes, mod_infos, modules_to_remove)
      when is_list(nodes) and is_list(mod_infos) and is_list(modules_to_remove) do
    for node <- nodes do
      :erpc.call(node, ExSyncLib.RemoteNl, :reload_unload, [mod_infos, modules_to_remove])
    end
  end

  def nl(nodes, module) when is_list(nodes) and is_atom(module) do
    case :code.get_object_code(module) do
      {^module, bin, beam_path} ->
        results =
          for node <- nodes do
            case :rpc.call(node, :code, :load_binary, [module, beam_path, bin]) do
              {:module, _} -> {node, :loaded, module}
              {:badrpc, message} -> {node, :badrpc, message}
              {:error, message} -> {node, :error, message}
              unexpected -> {node, :error, unexpected}
            end
          end

        {:ok, results}

      _otherwise ->
        {:error, :nofile}
    end
  end

  def nl(nodes, module, file, binary) when is_list(nodes) do
    for node <- nodes do
      :rpc.call(node, :code, :load_binary, [module, file, binary])
    end
  end
end
