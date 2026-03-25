# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../../lib/vb/bootstrap"

class VB::BootstrapTest < TLDR
  def setup
    @repo_root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@repo_root, ".vibe"))
  end

  def teardown
    FileUtils.rm_rf(@repo_root)
  end

  def test_needed_true_when_script_exists_but_no_image
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal true, bootstrap.needed?
  end

  def test_needed_false_when_image_exists
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")
    File.write(File.join(@repo_root, ".vibe", "instance.raw"), "img")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal false, bootstrap.needed?
  end

  def test_needed_false_when_no_script
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal false, bootstrap.needed?
  end

  def test_needed_false_when_image_exists_without_script
    File.write(File.join(@repo_root, ".vibe", "instance.raw"), "img")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal false, bootstrap.needed?
  end

  def test_script_path_returns_vibe_bootstrap_sh
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal File.join(@repo_root, ".vibe", "bootstrap.sh"), bootstrap.script_path
  end

  def test_image_path_returns_vibe_instance_raw
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal File.join(@repo_root, ".vibe", "instance.raw"), bootstrap.image_path
  end

  def test_global_script_path_returns_home_vb_bootstrap
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    assert_equal File.join(Dir.home, ".vb", "bootstrap.sh"), bootstrap.global_script_path
  end

  def test_run_builds_minimal_vibe_args
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")

    captured_args = nil
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) do |args, chdir: nil|
      captured_args = args
      true
    end

    bootstrap.run

    parent_dir = File.dirname(@repo_root)
    assert_includes captured_args, "--mount"
    assert captured_args.any? { |a| a == "#{parent_dir}:#{parent_dir}" }
    expect_indices = captured_args.each_index.select { |i| captured_args[i] == "--expect" }
    send_indices = captured_args.each_index.select { |i| captured_args[i] == "--send" }
    assert_equal 2, expect_indices.length
    assert_equal 2, send_indices.length
    assert_equal "root@vibe", captured_args[expect_indices.first + 1]
    assert_equal "root@vibe", captured_args[expect_indices.last + 1]
    last_send = captured_args[send_indices.last + 1]
    assert last_send.end_with?("bash .vibe/bootstrap.sh")

    joined = captured_args.join(" ")
    refute_includes joined, "command -v jj"
    refute_includes joined, "opencode"
    refute_includes joined, "mise"
  end

  def test_run_calls_vibe_from_repo_root
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")

    captured = nil
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) do |args, chdir: nil|
      captured = {args: args, chdir: chdir}
      true
    end

    bootstrap.run
    assert_equal @repo_root, captured[:chdir]
  end

  def test_run_raises_when_no_script
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)

    err = assert_raises(RuntimeError) { bootstrap.run }
    assert_includes err.message, "No bootstrap script"
  end

  def test_run_deletes_image_on_vibe_failure
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) do |args, chdir: nil|
      File.write(File.join(@repo_root, ".vibe", "instance.raw"), "img")
      false
    end

    assert_raises(RuntimeError) { bootstrap.run }
    refute File.exist?(bootstrap.image_path)
  end

  def test_run_raises_on_vibe_failure
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/usr/bin/env bash\n")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil| false }

    err = assert_raises(RuntimeError) { bootstrap.run }
    assert(err.message.include?("Bootstrap failed") || err.message.include?("vibe"))
  end

  def test_run_creates_lock_file_during_execution
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")

    lock_existed_during_run = false
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) do |args, chdir: nil|
      lock_path = File.join(@repo_root, ".vibe", ".bootstrap.lock")
      lock_existed_during_run = File.exist?(lock_path)
      true
    end

    bootstrap.run
    assert lock_existed_during_run, "lock file should exist during vibe execution"
  end

  def test_run_skips_vibe_if_image_exists_after_lock_acquired
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")
    # Image already exists — simulates another process having bootstrapped
    File.write(File.join(@repo_root, ".vibe", "instance.raw"), "img")

    vibe_called = false
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil|
      vibe_called = true
      true
    }

    bootstrap.run  # Should return early without calling vibe
    refute vibe_called, "vibe should not be called if image already exists after lock acquired"
  end

  def test_run_includes_global_mount_when_global_script_exists
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")

    captured_args = nil
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:global_script_exists?) { true }
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil|
      captured_args = args
      true
    }

    bootstrap.run

    joined = captured_args.join(" ")
    assert_includes joined, "/mnt/vb-global:ro"
    assert_includes joined, "bash /mnt/vb-global/bootstrap.sh && bash .vibe/bootstrap.sh"
  end

  def test_run_skips_global_mount_when_no_global_script
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")

    captured_args = nil
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:global_script_exists?) { false }
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil|
      captured_args = args
      true
    }

    bootstrap.run

    joined = captured_args.join(" ")
    refute_includes joined, "vb-global"
    refute_includes joined, "/mnt/vb-global"
    send_indices = captured_args.each_index.select { |i| captured_args[i] == "--send" }
    last_send = captured_args[send_indices.last + 1]
    assert last_send.end_with?("bash .vibe/bootstrap.sh")
    refute_includes last_send, "bash /mnt/vb-global/bootstrap.sh"
  end

  def test_run_global_script_runs_before_repo_script
    File.write(File.join(@repo_root, ".vibe", "bootstrap.sh"), "#!/bin/bash\n")

    captured_args = nil
    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:global_script_exists?) { true }
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil|
      captured_args = args
      true
    }

    bootstrap.run

    send_indices = captured_args.each_index.select { |i| captured_args[i] == "--send" }
    last_send = captured_args[send_indices.last + 1]
    global_pos = last_send.index("bash /mnt/vb-global/bootstrap.sh")
    repo_pos = last_send.index("bash .vibe/bootstrap.sh")
    refute_nil global_pos
    refute_nil repo_pos
    assert global_pos < repo_pos, "global script must run before repo script"
  end
end
