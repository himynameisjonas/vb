# frozen_string_literal: true

require "tmpdir"
require "fileutils"

class VB::VCSTest < TLDR
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_detect_returns_jj_when_jj_dir_exists
    FileUtils.mkdir_p(File.join(@dir, ".jj"))
    vcs = VB::VCS.detect(@dir)
    assert_instance_of VB::VCS::JJ, vcs
  end

  def test_detect_returns_git_when_git_dir_exists
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    vcs = VB::VCS.detect(@dir)
    assert_instance_of VB::VCS::Git, vcs
  end

  def test_detect_prefers_jj_when_both_exist
    FileUtils.mkdir_p(File.join(@dir, ".jj"))
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    vcs = VB::VCS.detect(@dir)
    assert_instance_of VB::VCS::JJ, vcs
  end

  def test_detect_raises_when_no_vcs_found
    err = assert_raises(RuntimeError) { VB::VCS.detect(@dir) }
    assert_includes err.message, "No supported VCS"
  end

  def test_base_add_workspace_raises
    vcs = VB::VCS::Adapter.new(repo_root: @dir)
    assert_raises(NotImplementedError) { vcs.add_workspace("/tmp/ws", name: "x") }
  end

  def test_base_forget_workspace_raises
    vcs = VB::VCS::Adapter.new(repo_root: @dir)
    assert_raises(NotImplementedError) { vcs.forget_workspace("/tmp/ws") }
  end

  def test_base_dirty_raises
    vcs = VB::VCS::Adapter.new(repo_root: @dir)
    assert_raises(NotImplementedError) { vcs.dirty?("/tmp/ws") }
  end

  def test_base_reset_to_latest_raises
    vcs = VB::VCS::Adapter.new(repo_root: @dir)
    assert_raises(NotImplementedError) { vcs.reset_to_latest("/tmp/ws") }
  end

  def test_base_config_mounts_raises
    vcs = VB::VCS::Adapter.new(repo_root: @dir)
    assert_raises(NotImplementedError) { vcs.config_mounts }
  end
end
