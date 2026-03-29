defmodule ResearchJobsRuntimeFoundationTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)

  test "research_jobs declares oban as its orchestration dependency" do
    mix_contents = mix_file_contents("research_jobs")

    assert mix_contents =~ "{:oban,"
  end

  test "research_jobs configures placeholder oban queues against the shared repo" do
    oban_config = Application.fetch_env!(:research_jobs, Oban)
    normalized_config = Oban.Config.new(oban_config)

    assert Keyword.fetch!(oban_config, :repo) == ResearchStore.Repo
    assert Keyword.fetch!(oban_config, :plugins) == []
    assert Keyword.fetch!(oban_config, :testing) == :inline
    assert normalized_config.notifier == {Oban.Notifiers.PG, []}

    assert Keyword.fetch!(oban_config, :queues) == [
             control: 10,
             orchestration: 10,
             maintenance: 5
           ]
  end

  test "research_jobs application owns the oban runtime child" do
    assert is_pid(Process.whereis(ResearchJobs.Supervisor))

    assert Enum.any?(Supervisor.which_children(ResearchJobs.Supervisor), fn
             {Oban, pid, _child_type, modules} ->
               is_pid(pid) and Oban in List.wrap(modules)

             _other ->
               false
           end)
  end

  defp mix_file_contents(app_name) do
    Path.join([@repo_root, "apps", app_name, "mix.exs"])
    |> File.read!()
  end
end
