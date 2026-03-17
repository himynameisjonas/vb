# frozen_string_literal: true

class VB::WorkspaceTest < TLDR
  def setup
    @workspace = VB::Workspace.new(
      workspace_dir: "/tmp/myrepo-swift-falcon",
      repo_root: "/tmp/myrepo"
    )
    @jj_calls = []
    @workspace.define_singleton_method(:run_jj) do |args, chdir: nil|
      @jj_calls << {args: args, chdir: chdir}
      true
    end
    @workspace.instance_variable_set(:@jj_calls, @jj_calls)
  end

  def test_add_calls_jj_workspace_add
    @workspace.add
    assert_equal 1, @jj_calls.length
    assert_includes @jj_calls[0][:args], "workspace"
    assert_includes @jj_calls[0][:args], "add"
    assert_includes @jj_calls[0][:args], "/tmp/myrepo-swift-falcon"
  end

  def test_forget_calls_jj_workspace_forget
    @workspace.forget
    assert_equal 1, @jj_calls.length
    assert_includes @jj_calls[0][:args], "workspace"
    assert_includes @jj_calls[0][:args], "forget"
    assert_includes @jj_calls[0][:args], "swift-falcon"
  end
end
