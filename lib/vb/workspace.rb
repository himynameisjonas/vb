# frozen_string_literal: true

module VB
  class Workspace
    def initialize(workspace_dir:, repo_root:)
      @workspace_dir = workspace_dir
      @repo_root = repo_root
    end

    def add
      run_jj(["workspace", "add", @workspace_dir], chdir: @repo_root)
    end

    def forget
      name = File.basename(@workspace_dir)
      run_jj(["workspace", "forget", name], chdir: @workspace_dir)
    end

    private

    def run_jj(args, chdir: nil)
      opts = chdir ? {chdir: chdir} : {}
      system("jj", *args, **opts)
    end
  end
end
