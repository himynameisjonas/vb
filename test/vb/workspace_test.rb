# frozen_string_literal: true

class VB::WorkspaceTest < TLDR
  def setup
    @workspace = VB::Workspace.new(
      workspace_dir: "/tmp/myrepo-swift-falcon",
      repo_root: "/tmp/myrepo"
    )
    @jj_calls = []
    @workspace.define_singleton_method(:run_jj) do |args, chdir: nil|
      @jj_calls << {args: args, chdir: chdir}
      true
    end
    @workspace.instance_variable_set(:@jj_calls, @jj_calls)
  end

  def test_add_calls_jj_workspace_add
    @workspace.add
    assert_equal 1, @jj_calls.length
    assert_includes @jj_calls[0][:args], "workspace"
    assert_includes @jj_calls[0][:args], "add"
    assert_includes @jj_calls[0][:args], "/tmp/myrepo-swift-falcon"
  end

  def test_forget_calls_jj_workspace_forget
    @workspace.forget
    assert_equal 1, @jj_calls.length
    assert_includes @jj_calls[0][:args], "workspace"
    assert_includes @jj_calls[0][:args], "forget"
    assert_includes @jj_calls[0][:args], "swift-falcon"
  end

  def test_forget_runs_from_repo_root_not_workspace_dir
    @workspace.forget
    assert_equal "/tmp/myrepo", @jj_calls[0][:chdir],
      "forget must run from repo_root so jj can find the workspace; running from workspace_dir causes 'No such workspace' warning"
  end

  def test_dirty_returns_true_when_changes_present
    fake_ok = Object.new
    def fake_ok.success? = true
    @workspace.define_singleton_method(:run_jj_capture) do |args, chdir: nil|
      ["Working copy changes:\nM foo.rb\n", fake_ok]
    end
    assert @workspace.dirty?
  end

  def test_dirty_returns_false_when_no_changes
    fake_ok = Object.new
    def fake_ok.success? = true
    @workspace.define_singleton_method(:run_jj_capture) do |args, chdir: nil|
      ["The working copy has no changes.\n", fake_ok]
    end
    refute @workspace.dirty?
  end

  def test_dirty_returns_true_when_jj_exits_nonzero
    fake_status = Object.new
    def fake_status.success? = false
    @workspace.define_singleton_method(:run_jj_capture) { |args, chdir: nil| ["Error: no repo", fake_status] }
    assert @workspace.dirty?
  end

  def test_reset_to_latest_calls_jj_edit_trunk
    @workspace.reset_to_latest
    assert_equal 1, @jj_calls.length
    assert_includes @jj_calls[0][:args], "edit"
    assert_includes @jj_calls[0][:args], "trunk"
  end

  def test_add_passes_name_flag_when_provided
    @workspace.add(name: "swift-falcon")
    assert_includes @jj_calls[0][:args], "--name"
    assert_includes @jj_calls[0][:args], "swift-falcon"
  end

  def test_add_omits_name_flag_when_nil
    @workspace.add
    refute @jj_calls[0][:args].include?("--name")
  end
end
