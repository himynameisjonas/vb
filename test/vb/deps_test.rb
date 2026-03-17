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
end
