# frozen_string_literal: true

module VB
  class Workspace
    def initialize(workspace_dir:, repo_root:, vcs: nil)
      @workspace_dir = workspace_dir
      @repo_root = repo_root
      @vcs = vcs || VCS.detect(repo_root)
    end

    def add(name: nil)
      @vcs.add_workspace(@workspace_dir, name: name)
    end

    def forget
      @vcs.forget_workspace(@workspace_dir)
    end

    def dirty?
      @vcs.dirty?(@workspace_dir)
    end

    def reset_to_latest
      @vcs.reset_to_latest(@workspace_dir)
    end
  end
end
