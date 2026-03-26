# frozen_string_literal: true

class VB::VCS::GitTest < TLDR
  def setup
    @vcs = VB::VCS::Git.new(repo_root: "/tmp/myrepo")
    @calls = []
    @vcs.define_singleton_method(:run_cmd) do |args, chdir: nil|
      @calls << {args: args, chdir: chdir}
      true
    end
    @vcs.instance_variable_set(:@calls, @calls)
  end

  def test_add_workspace_calls_git_worktree_add_detached
    @vcs.add_workspace("/tmp/myrepo-swift-falcon")
    assert_equal 1, @calls.length
    assert_equal ["git", "worktree", "add", "--detach", "/tmp/myrepo-swift-falcon"], @calls[0][:args]
    assert_equal "/tmp/myrepo", @calls[0][:chdir]
  end

  def test_add_workspace_ignores_name_param
    @vcs.add_workspace("/tmp/myrepo-swift-falcon", name: "swift-falcon")
    refute @calls[0][:args].include?("--name")
    refute @calls[0][:args].include?("swift-falcon")
  end

  def test_forget_workspace_calls_git_worktree_remove
    @vcs.forget_workspace("/tmp/myrepo-swift-falcon")
    assert_equal ["git", "worktree", "remove", "--force", "/tmp/myrepo-swift-falcon"], @calls[0][:args]
    assert_equal "/tmp/myrepo", @calls[0][:chdir]
  end

  def test_dirty_returns_true_when_changes_present
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      [" M foo.rb\n", fake_ok]
    end
    assert @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_dirty_returns_false_when_no_changes
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["", fake_ok]
    end
    refute @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_dirty_returns_true_when_command_fails
    fake_status = Object.new
    def fake_status.success? = false
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["fatal: not a git repo", fake_status]
    end
    assert @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_dirty_uses_porcelain_flag
    captured_args = nil
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |args, chdir: nil|
      captured_args = args
      ["", fake_ok]
    end
    @vcs.dirty?("/tmp/myrepo-swift-falcon")
    assert_includes captured_args, "--porcelain"
  end

  def test_reset_to_latest_fetches_then_resets
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["refs/remotes/origin/main\n", fake_ok]
    end
    @vcs.reset_to_latest("/tmp/myrepo-swift-falcon")
    assert_equal 2, @calls.length
    assert_equal %w[git fetch origin], @calls[0][:args]
    assert_equal "/tmp/myrepo-swift-falcon", @calls[0][:chdir]
  end

  def test_reset_to_latest_detects_default_branch
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["refs/remotes/origin/main\n", fake_ok]
    end
    @vcs.reset_to_latest("/tmp/myrepo-swift-falcon")
    reset_call = @calls.find { |c| c[:args].include?("reset") }
    assert_includes reset_call[:args], "origin/main"
  end

  def test_reset_to_latest_falls_back_to_main_on_detection_failure
    fake_fail = Object.new
    def fake_fail.success? = false
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["", fake_fail]
    end
    @vcs.reset_to_latest("/tmp/myrepo-swift-falcon")
    reset_call = @calls.find { |c| c[:args].include?("reset") }
    assert_includes reset_call[:args], "origin/main"
  end

  def test_config_mounts_includes_gitconfig
    mounts = @vcs.config_mounts
    assert(mounts.any? { |m| m.include?(".gitconfig") })
  end

  def test_config_mounts_includes_ssh
    mounts = @vcs.config_mounts
    assert(mounts.any? { |m| m.include?(".ssh") })
  end
end
