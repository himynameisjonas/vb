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
end
