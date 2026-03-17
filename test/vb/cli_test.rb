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

  def test_default_calls_pool_acquire
    acquired = []
    @fake_pool.define_singleton_method(:acquire) { |send_cmd: "opencode"|
      acquired << send_cmd
      "swift-falcon"
    }
    out = capture_output { VB::CLI.start([]) }
    assert_includes acquired, "opencode"
    assert_includes out, "swift-falcon"
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
