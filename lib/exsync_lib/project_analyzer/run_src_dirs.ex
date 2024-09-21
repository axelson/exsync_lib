defmodule ExSyncLib.ProjectAnalyzer.RunSrcDirs do
  def run(mixfile_path, build_path) do
    src_dirs_script_path = Path.join(__DIR__, "src_dirs.exs")

    command =
      "Code.eval_file(\"#{src_dirs_script_path}\"); ExSyncLib.ProjectAnalyzer.SrcDirs.run(\"#{mixfile_path}\", \"#{build_path}\")"

    case System.cmd("elixir", ["-e", command],
           cd: Path.dirname(mixfile_path),
           # TODO: Pass appropriate MIX_TARGET in to function
           env: build_env("rpi0")
         ) do
      {_output, 0} ->
        :ok

      err ->
        raise "Unable to get src dirs due to error: #{inspect(err)}"
    end
  end

  defp build_env(mix_target) do
    beam_notify_env = Enum.to_list(BEAMNotify.env(ExSyncLib.Config.beam_notify_name))

    [{"MIX_TARGET", mix_target}] ++ beam_notify_env
  end
end
