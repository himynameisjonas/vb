# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "digest"

class VB::StateTest < TLDR
  def setup
    @tmpdir = Dir.mktmpdir
    @repo_root = @tmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_creates_state_file_on_first_write
    VB::State.with_lock(repo_root: @repo_root) { |s| s["workspaces"] = {} }
    digest = Digest::SHA256.hexdigest(@repo_root)[0..5]
    path = File.join(Dir.home, ".local", "share", "vb", digest, "state.json")
    assert File.exist?(path)
    FileUtils.rm_rf(File.dirname(path))
  end

  def test_reads_empty_hash_when_no_file
    result = nil
    VB::State.with_lock(repo_root: @repo_root) { |s| result = s }
    FileUtils.rm_rf(state_dir)
    assert_equal({}, result)
  end

  private

  def state_dir
    digest = Digest::SHA256.hexdigest(@repo_root)[0..5]
    File.join(Dir.home, ".local", "share", "vb", digest)
  end
end
