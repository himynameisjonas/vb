# frozen_string_literal: true

require "stringio"

class VB::CLITest < TLDR
  def setup
    @fake_pool = Object.new
    @original_factory = VB::CLI.pool_factory
    VB::CLI.pool_factory = ->(**) { @fake_pool }
  end

  def teardown
    VB::CLI.pool_factory = @original_factory
  end

  def test_status_prints_no_workspaces_when_empty
    def @fake_pool.list = []
    out = capture_output { VB::CLI.start(["status"]) }
    assert_includes out, "No workspaces"
  end

  def test_status_prints_workspace_info
    def @fake_pool.list
      [{name: "swift-falcon", workspace_dir: "/tmp/repo-swift-falcon", in_use: false, dirty: false}]
    end
    out = capture_output { VB::CLI.start(["status"]) }
    assert_includes out, "swift-falcon"
    assert_includes out, "available"
  end

  def test_status_shows_in_use
    def @fake_pool.list
      [{name: "brave-hawk", workspace_dir: "/tmp/repo-brave-hawk", in_use: true, dirty: false}]
    end
    out = capture_output { VB::CLI.start(["status"]) }
    assert_includes out, "in-use"
  end

  def test_destroy_calls_pool_destroy
    destroyed = []
    @fake_pool.define_singleton_method(:destroy) { |name:| destroyed << name }
    capture_output { VB::CLI.start(["destroy", "swift-falcon"]) }
    assert_includes destroyed, "swift-falcon"
  end

  def test_destroy_all_calls_pool_destroy_all
    called = false
    @fake_pool.define_singleton_method(:destroy_all) { called = true }
    capture_output { VB::CLI.start(["destroy", "--all"]) }
    assert called
  end

  def test_default_with_no_args_drops_to_shell
    acquired = []
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: nil, resume_cmd: nil|
      acquired << send_cmd
      {name: "swift-falcon", resumed: false}
    }
    capture_output { VB::CLI.start([]) }
    assert_equal [nil], acquired
  end

  def test_opencode_command
    acquired = []
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "bash", resume_cmd: nil|
      acquired << send_cmd
      {name: "swift-falcon", resumed: false}
    }
    out = capture_output { VB::CLI.start(["opencode"]) }
    assert_equal ["opencode"], acquired
    assert_includes out, "swift-falcon"
  end

  def test_claude_command_adds_skip_permissions
    acquired = []
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "bash", resume_cmd: nil|
      acquired << send_cmd
      {name: "swift-falcon", resumed: false}
    }
    out = capture_output { VB::CLI.start(["claude"]) }
    assert_equal ["claude --dangerously-skip-permissions"], acquired
    assert_includes out, "swift-falcon"
  end

  def test_acquire_prints_creating_for_new_workspace
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "bash", resume_cmd: nil|
      {name: "swift-falcon", resumed: false}
    }
    out = capture_output { VB::CLI.start([]) }
    assert_includes out, "Creating workspace: swift-falcon"
  end

  def test_acquire_prints_resuming_for_existing_workspace
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "bash", resume_cmd: nil|
      {name: "brave-hawk", resumed: true}
    }
    out = capture_output { VB::CLI.start([]) }
    assert_includes out, "Resuming workspace: brave-hawk"
  end

  def test_claude_passes_continue_as_resume_cmd
    acquired_resume_cmd = nil
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "bash", resume_cmd: nil|
      acquired_resume_cmd = resume_cmd
      {name: "swift-falcon", resumed: true}
    }
    capture_output { VB::CLI.start(["claude"]) }
    assert_includes acquired_resume_cmd, "--continue"
  end

  private

  def capture_output(&block)
    old_stdout = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
