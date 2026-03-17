# frozen_string_literal: true

require "open3"

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
      repo_prefix = "#{File.basename(@repo_root)}-"
      name = File.basename(@workspace_dir).delete_prefix(repo_prefix)
      run_jj(["workspace", "forget", name], chdir: @workspace_dir)
    end

    def dirty?
      output, status = run_jj_capture(["status"], chdir: @workspace_dir)
      return true unless status.success?  # fail closed: errors = dirty
      output.include?("Working copy changes:")
    end

    def reset_to_latest
      run_jj(["edit", "trunk"], chdir: @workspace_dir)
    end

    private

    def run_jj(args, chdir: nil)
      opts = chdir ? {chdir: chdir} : {}
      system("jj", *args, **opts)
    end

    def run_jj_capture(args, chdir: nil)
      dir = chdir || Dir.pwd
      Open3.capture2e("jj", *args, chdir: dir)
    end
  end
end
