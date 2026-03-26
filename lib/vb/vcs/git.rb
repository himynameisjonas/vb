# frozen_string_literal: true

require "open3"

module VB
  module VCS
    class Git < Adapter
      def add_workspace(workspace_dir, name: nil)
        run_cmd(["git", "worktree", "add", "--detach", workspace_dir], chdir: @repo_root)
      end

      def forget_workspace(workspace_dir)
        run_cmd(["git", "worktree", "remove", "--force", workspace_dir], chdir: @repo_root)
      end

      def dirty?(workspace_dir)
        output, status = run_cmd_capture(["git", "status", "--porcelain"], chdir: workspace_dir)
        return true unless status.success?

        !output.strip.empty?
      end

      def reset_to_latest(workspace_dir)
        run_cmd(%w[git fetch origin], chdir: workspace_dir)
        branch = detect_default_branch(workspace_dir)
        run_cmd(["git", "reset", "--hard", "origin/#{branch}"], chdir: workspace_dir)
      end

      def config_mounts
        [
          "#{Dir.home}/.gitconfig:/root/.gitconfig",
          "#{Dir.home}/.ssh:/root/.ssh"
        ]
      end

      private

      def detect_default_branch(workspace_dir)
        output, status = run_cmd_capture(
          ["git", "symbolic-ref", "refs/remotes/origin/HEAD"],
          chdir: workspace_dir
        )
        if status.success?
          output.strip.sub(%r{^refs/remotes/origin/}, "")
        else
          "main"
        end
      end

      def run_cmd(args, chdir: nil)
        opts = chdir ? {chdir: chdir} : {}
        system(*args, **opts)
      end

      def run_cmd_capture(args, chdir: nil)
        dir = chdir || Dir.pwd
        Open3.capture2e(*args, chdir: dir)
      end
    end
  end
end
