# frozen_string_literal: true

require "open3"

module VB
  module VCS
    class JJ < Adapter
      def add_workspace(workspace_dir, name: nil)
        args = ["jj", "workspace", "add", workspace_dir]
        args.push("--name", name) if name
        run_cmd(args, chdir: @repo_root)
      end

      def forget_workspace(workspace_dir)
        repo_prefix = "#{File.basename(@repo_root)}-"
        ws_name = File.basename(workspace_dir).delete_prefix(repo_prefix)
        run_cmd(["jj", "workspace", "forget", ws_name], chdir: @repo_root)
      end

      def dirty?(workspace_dir)
        output, status = run_cmd_capture(%w[jj status], chdir: workspace_dir)
        return true unless status.success?

        output.include?("Working copy changes:")
      end

      def reset_to_latest(workspace_dir)
        run_cmd(["jj", "new", "trunk()"], chdir: workspace_dir)
      end

      def config_mounts
        ["#{Dir.home}/.config/jj:/root/.config/jj"]
      end

      private

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
