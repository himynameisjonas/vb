# frozen_string_literal: true

require "tmpdir"
require "fileutils"

class VB::DepsTest < TLDR
  def setup
    @repo_dir = Dir.mktmpdir
    @workspace_dir = Dir.mktmpdir
    @deps = VB::Deps.new(repo_root: @repo_dir, workspace_dir: @workspace_dir)
  end

  def teardown
    FileUtils.rm_rf(@repo_dir)
    FileUtils.rm_rf(@workspace_dir)
  end

  def test_no_lockfiles_means_up_to_date
    assert @deps.up_to_date?
  end

  def test_identical_lockfile_is_not_stale
    File.write(File.join(@repo_dir, "Gemfile.lock"), "same content")
    File.write(File.join(@workspace_dir, "Gemfile.lock"), "same content")
    assert @deps.up_to_date?
  end

  def test_differing_lockfile_is_stale
    File.write(File.join(@repo_dir, "Gemfile.lock"), "new content")
    File.write(File.join(@workspace_dir, "Gemfile.lock"), "old content")
    assert_includes @deps.stale_lockfiles, "Gemfile.lock"
  end

  def test_missing_workspace_lockfile_is_stale
    File.write(File.join(@repo_dir, "Gemfile.lock"), "content")
    assert_includes @deps.stale_lockfiles, "Gemfile.lock"
  end

  def test_install_commands_for_stale_gemfile_lock
    File.write(File.join(@repo_dir, "Gemfile.lock"), "new")
    File.write(File.join(@workspace_dir, "Gemfile.lock"), "old")
    assert_includes @deps.install_commands, "bundle install"
  end

  def test_install_commands_for_pnpm_lock
    File.write(File.join(@repo_dir, "pnpm-lock.yaml"), "new")
    assert_includes @deps.install_commands, "pnpm install"
  end

  def test_detects_stale_lockfile_in_subdirectory
    subdir = File.join(@repo_dir, "ember_app")
    ws_subdir = File.join(@workspace_dir, "ember_app")
    FileUtils.mkdir_p(subdir)
    FileUtils.mkdir_p(ws_subdir)
    File.write(File.join(subdir, "pnpm-lock.yaml"), "new")
    File.write(File.join(ws_subdir, "pnpm-lock.yaml"), "old")
    assert_includes @deps.stale_lockfiles, "ember_app/pnpm-lock.yaml"
  end

  def test_install_command_for_subdirectory_lockfile
    subdir = File.join(@repo_dir, "ember_app")
    FileUtils.mkdir_p(subdir)
    File.write(File.join(subdir, "pnpm-lock.yaml"), "content")
    assert_includes @deps.install_commands, "cd ember_app && pnpm install"
  end

  def test_identical_subdir_lockfile_is_not_stale
    subdir = File.join(@repo_dir, "ember_app")
    ws_subdir = File.join(@workspace_dir, "ember_app")
    FileUtils.mkdir_p(subdir)
    FileUtils.mkdir_p(ws_subdir)
    File.write(File.join(subdir, "pnpm-lock.yaml"), "same")
    File.write(File.join(ws_subdir, "pnpm-lock.yaml"), "same")
    refute_includes @deps.stale_lockfiles, "ember_app/pnpm-lock.yaml"
  end

  def test_does_not_scan_deeper_than_one_level
    deep = File.join(@repo_dir, "a", "b")
    FileUtils.mkdir_p(deep)
    File.write(File.join(deep, "Gemfile.lock"), "content")
    assert @deps.up_to_date?
  end
end
