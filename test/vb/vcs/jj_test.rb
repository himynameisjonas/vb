# frozen_string_literal: true

class VB::VCS::JJTest < TLDR
  def setup
    @vcs = VB::VCS::JJ.new(repo_root: "/tmp/myrepo")
    @calls = []
    @vcs.define_singleton_method(:run_cmd) do |args, chdir: nil|
      @calls << {args: args, chdir: chdir}
      true
    end
    @vcs.instance_variable_set(:@calls, @calls)
  end

  def test_add_workspace_calls_jj_workspace_add
    @vcs.add_workspace("/tmp/myrepo-swift-falcon")
    assert_equal 1, @calls.length
    assert_equal ["jj", "workspace", "add", "/tmp/myrepo-swift-falcon"], @calls[0][:args]
    assert_equal "/tmp/myrepo", @calls[0][:chdir]
  end

  def test_add_workspace_passes_name_flag_when_provided
    @vcs.add_workspace("/tmp/myrepo-swift-falcon", name: "swift-falcon")
    assert_equal ["jj", "workspace", "add", "/tmp/myrepo-swift-falcon", "--name", "swift-falcon"], @calls[0][:args]
  end

  def test_add_workspace_omits_name_flag_when_nil
    @vcs.add_workspace("/tmp/myrepo-swift-falcon")
    refute @calls[0][:args].include?("--name")
  end

  def test_forget_workspace_calls_jj_workspace_forget
    @vcs.forget_workspace("/tmp/myrepo-swift-falcon")
    assert_equal %w[jj workspace forget swift-falcon], @calls[0][:args]
  end

  def test_forget_workspace_runs_from_repo_root
    @vcs.forget_workspace("/tmp/myrepo-swift-falcon")
    assert_equal "/tmp/myrepo", @calls[0][:chdir]
  end

  def test_dirty_returns_true_when_changes_present
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["Working copy changes:\nM foo.rb\n", fake_ok]
    end
    assert @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_dirty_returns_false_when_no_changes
    fake_ok = Object.new
    def fake_ok.success? = true
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["The working copy has no changes.\n", fake_ok]
    end
    refute @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_dirty_returns_true_when_command_fails
    fake_status = Object.new
    def fake_status.success? = false
    @vcs.define_singleton_method(:run_cmd_capture) do |_args, chdir: nil|
      ["Error: no repo", fake_status]
    end
    assert @vcs.dirty?("/tmp/myrepo-swift-falcon")
  end

  def test_reset_to_latest_calls_jj_new_trunk
    @vcs.reset_to_latest("/tmp/myrepo-swift-falcon")
    assert_equal ["jj", "new", "trunk()"], @calls[0][:args]
    assert_equal "/tmp/myrepo-swift-falcon", @calls[0][:chdir]
  end

  def test_config_mounts_includes_jj_config
    mounts = @vcs.config_mounts
    assert_equal 1, mounts.length
    assert mounts[0].include?(".config/jj")
    assert mounts[0].include?("/root/.config/jj")
  end
end
