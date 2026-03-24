# frozen_string_literal: true

require "fileutils"
require "stringio"
require "tmpdir"

class VB::CLITest < TLDR
  run_these_together!

  def setup
    @fake_pool = Object.new
    @original_pool_factory = VB::CLI.pool_factory
    VB::CLI.pool_factory = ->(**) { @fake_pool }

    @fake_bootstrap = Object.new
    @original_bootstrap_factory = VB::CLI.bootstrap_factory
    VB::CLI.bootstrap_factory = ->(**) { @fake_bootstrap }
  end

  def teardown
    VB::CLI.pool_factory = @original_pool_factory
    VB::CLI.bootstrap_factory = @original_bootstrap_factory
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

  def test_bootstrap_edit_creates_script_when_missing
    dir = Dir.mktmpdir
    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    old_editor = ENV["EDITOR"]
    ENV["EDITOR"] = "/nonexistent-vb-test-editor"
    begin
      capture_output { VB::CLI.start(["bootstrap", "--edit"]) }
    rescue Errno::ENOENT
    ensure
      ENV["EDITOR"] = old_editor
    end

    script = File.join(dir, ".vibe", "bootstrap.sh")
    assert File.exist?(script), "bootstrap.sh should be created"
    assert_includes File.read(script), "#!/bin/bash"
    assert File.executable?(script), "bootstrap.sh should be executable"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_edit_does_not_recreate_existing_script
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, ".vibe"))
    File.write(File.join(dir, ".vibe", "bootstrap.sh"), "#!/bin/bash\n# EXISTING\n")
    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    old_editor = ENV["EDITOR"]
    ENV["EDITOR"] = "/nonexistent-vb-test-editor"
    begin
      capture_output { VB::CLI.start(["bootstrap", "--edit"]) }
    rescue Errno::ENOENT
    ensure
      ENV["EDITOR"] = old_editor
    end

    content = File.read(File.join(dir, ".vibe", "bootstrap.sh"))
    assert_includes content, "# EXISTING", "should preserve existing script content"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_rebuild_errors_when_no_script
    dir = Dir.mktmpdir
    run_called = false
    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    fake_bootstrap.define_singleton_method(:run) { run_called = true }
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    begin
      capture_output { VB::CLI.start(["bootstrap"]) }
    rescue SystemExit
    end

    refute run_called, "bootstrap.run must not be called when no script exists"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_rebuild_runs_bootstrap_when_no_image
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, ".vibe"))
    File.write(File.join(dir, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")

    run_called = false
    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    fake_bootstrap.define_singleton_method(:run) do
      run_called = true
      File.write(File.join(dir, ".vibe", "instance.raw"), "img")
    end
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    def @fake_pool.list = []

    out = capture_output { VB::CLI.start(["bootstrap"]) }
    assert run_called, "bootstrap.run should be called"
    assert_includes out, "Bootstrapping"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_rebuild_warns_about_existing_workspaces
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, ".vibe"))
    File.write(File.join(dir, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")
    File.write(File.join(dir, ".vibe", "instance.raw"), "img")

    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    fake_bootstrap.define_singleton_method(:run) do
      File.write(File.join(dir, ".vibe", "instance.raw"), "img")
    end
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    @fake_pool.define_singleton_method(:list) { [{name: "ws1"}, {name: "ws2"}] }
    @fake_pool.define_singleton_method(:destroy_all) {}

    old_stdin = $stdin
    $stdin = StringIO.new("n\n")
    out = capture_output { VB::CLI.start(["bootstrap"]) }
    $stdin = old_stdin

    assert_includes out, "2 workspace"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_rebuild_destroys_workspaces_when_confirmed
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, ".vibe"))
    File.write(File.join(dir, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")
    File.write(File.join(dir, ".vibe", "instance.raw"), "img")

    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    fake_bootstrap.define_singleton_method(:run) do
      File.write(File.join(dir, ".vibe", "instance.raw"), "img")
    end
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    destroy_called = false
    @fake_pool.define_singleton_method(:list) { [{name: "old-ws"}] }
    @fake_pool.define_singleton_method(:destroy_all) { destroy_called = true }

    old_stdin = $stdin
    $stdin = StringIO.new("y\n")
    capture_output { VB::CLI.start(["bootstrap"]) }
    $stdin = old_stdin

    assert destroy_called, "destroy_all should be called when user confirms"
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_bootstrap_rebuild_skips_destroy_when_declined
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, ".vibe"))
    File.write(File.join(dir, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")
    File.write(File.join(dir, ".vibe", "instance.raw"), "img")

    fake_bootstrap = VB::Bootstrap.new(repo_root: dir)
    fake_bootstrap.define_singleton_method(:run) do
      File.write(File.join(dir, ".vibe", "instance.raw"), "img")
    end
    VB::CLI.bootstrap_factory = ->(**) { fake_bootstrap }

    destroy_called = false
    @fake_pool.define_singleton_method(:list) { [{name: "keep-ws"}] }
    @fake_pool.define_singleton_method(:destroy_all) { destroy_called = true }

    old_stdin = $stdin
    $stdin = StringIO.new("n\n")
    capture_output { VB::CLI.start(["bootstrap"]) }
    $stdin = old_stdin

    refute destroy_called, "destroy_all must NOT be called when user declines"
  ensure
    FileUtils.rm_rf(dir)
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
