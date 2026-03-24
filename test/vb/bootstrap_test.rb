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
    File.write(File.join(@repo_root, ".vibe", "instance.raw"), "img")

    bootstrap = VB::Bootstrap.new(repo_root: @repo_root)
    bootstrap.define_singleton_method(:run_vibe) { |args, chdir: nil| false }

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
end
