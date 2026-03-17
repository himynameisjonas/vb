# frozen_string_literal: true

class VB::ProcessTest < TLDR
  def test_in_use_returns_true_when_dir_appears_in_ps
    process = VB::Process.new
    def process.ps_output
      "501 1234 ruby /home/user/myrepo-swift-falcon/some_script.rb\n"
    end
    assert process.in_use?(workspace_dir: "/home/user/myrepo-swift-falcon")
  end

  def test_in_use_returns_false_when_dir_not_in_ps
    process = VB::Process.new
    def process.ps_output
      "501 1234 ruby /other/path/script.rb\n"
    end
    refute process.in_use?(workspace_dir: "/home/user/myrepo-swift-falcon")
  end

  def test_in_use_dirs_returns_only_matching_dirs
    process = VB::Process.new
    def process.ps_output
      "501 1234 ruby /repo-alpha/script.rb\n501 5678 node /repo-beta/server.js\n"
    end
    result = process.in_use_dirs(workspace_dirs: ["/repo-alpha", "/repo-gamma"])
    assert_equal ["/repo-alpha"], result
  end
end
