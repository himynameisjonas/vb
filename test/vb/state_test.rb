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

  def test_persists_data_across_calls
    VB::State.with_lock(repo_root: @repo_root) { |s| s["foo"] = "bar" }
    result = nil
    VB::State.with_lock(repo_root: @repo_root) { |s| result = s["foo"] }
    FileUtils.rm_rf(state_dir)
    assert_equal "bar", result
  end

  def test_heals_missing_workspace_dirs
    VB::State.with_lock(repo_root: @repo_root) do |s|
      s["workspaces"] = {
        "alive" => {"workspace_dir" => @tmpdir},
        "dead" => {"workspace_dir" => "/nonexistent/path/xyz"}
      }
    end
    result = nil
    VB::State.with_lock(repo_root: @repo_root) { |s| result = s["workspaces"] }
    FileUtils.rm_rf(state_dir)
    assert result.key?("alive")
    refute result.key?("dead")
  end

  private

  def state_dir
    digest = Digest::SHA256.hexdigest(@repo_root)[0..5]
    File.join(Dir.home, ".local", "share", "vb", digest)
  end
end
