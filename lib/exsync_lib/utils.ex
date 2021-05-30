defmodule ExSyncLib.Utils do
  def recomplete do
    ExSyncLib.Logger.debug("running mix compile")

    System.cmd("mix", ["compile"], cd: ExSyncLib.Config.app_source_dir(), stderr_to_stdout: true)
    |> log_compile_cmd()
  end

  def unload(module) when is_atom(module) do
    ExSyncLib.Logger.debug("unload module #{inspect module}")
    module |> :code.purge()
    module |> :code.delete()
  end

  def unload(beam_path) do
    beam_path |> Path.basename(".beam") |> String.to_atom() |> unload
  end

  # beam file path
  def reload(beam_path) do
    ExSyncLib.Logger.debug("reload module #{Path.basename(beam_path, ".beam")}")
    file = beam_path |> to_charlist
    {:ok, binary, _} = :erl_prim_loader.get_file(file)
    module = beam_path |> Path.basename(".beam") |> String.to_atom()
    :code.load_binary(module, file, binary)
  end

  defp log_compile_cmd({output, status} = result) when is_binary(output) and status > 0 do
    ExSyncLib.Logger.error(["error while compiling\n", output])
    result
  end

  defp log_compile_cmd({"", _status} = result), do: result

  defp log_compile_cmd({output, _status} = result) when is_binary(output) do
    message = ["compiling\n", output]

    if String.contains?(output, "warning:") do
      ExSyncLib.Logger.warn(message)
    else
      ExSyncLib.Logger.debug(message)
    end

    result
  end
end
