# frozen_string_literal: true

class VB::WorkspaceTest < TLDR
  def setup
    @vcs_calls = []
    @fake_vcs = Object.new
    calls = @vcs_calls
    @fake_vcs.define_singleton_method(:add_workspace) do |dir, name: nil|
      calls << {method: :add_workspace, dir: dir, name: name}
    end
    @fake_vcs.define_singleton_method(:forget_workspace) do |dir|
      calls << {method: :forget_workspace, dir: dir}
    end
    @fake_vcs.define_singleton_method(:dirty?) do |dir|
      calls << {method: :dirty?, dir: dir}
      false
    end
    @fake_vcs.define_singleton_method(:reset_to_latest) do |dir|
      calls << {method: :reset_to_latest, dir: dir}
    end

    @workspace = VB::Workspace.new(
      workspace_dir: "/tmp/myrepo-swift-falcon",
      repo_root: "/tmp/myrepo",
      vcs: @fake_vcs
    )
  end

  def test_add_delegates_to_vcs
    @workspace.add
    assert_equal 1, @vcs_calls.length
    assert_equal :add_workspace, @vcs_calls[0][:method]
    assert_equal "/tmp/myrepo-swift-falcon", @vcs_calls[0][:dir]
  end

  def test_add_passes_name_to_vcs
    @workspace.add(name: "swift-falcon")
    assert_equal "swift-falcon", @vcs_calls[0][:name]
  end

  def test_add_passes_nil_name_when_not_provided
    @workspace.add
    assert_nil @vcs_calls[0][:name]
  end

  def test_forget_delegates_to_vcs
    @workspace.forget
    assert_equal 1, @vcs_calls.length
    assert_equal :forget_workspace, @vcs_calls[0][:method]
    assert_equal "/tmp/myrepo-swift-falcon", @vcs_calls[0][:dir]
  end

  def test_dirty_delegates_to_vcs
    @workspace.dirty?
    assert_equal 1, @vcs_calls.length
    assert_equal :dirty?, @vcs_calls[0][:method]
    assert_equal "/tmp/myrepo-swift-falcon", @vcs_calls[0][:dir]
  end

  def test_dirty_returns_vcs_result
    @fake_vcs.define_singleton_method(:dirty?) { |_dir| true }
    assert @workspace.dirty?
  end

  def test_reset_to_latest_delegates_to_vcs
    @workspace.reset_to_latest
    assert_equal 1, @vcs_calls.length
    assert_equal :reset_to_latest, @vcs_calls[0][:method]
    assert_equal "/tmp/myrepo-swift-falcon", @vcs_calls[0][:dir]
  end
end
