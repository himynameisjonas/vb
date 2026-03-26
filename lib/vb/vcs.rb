# frozen_string_literal: true

module VB
  module VCS
    def self.detect(repo_root)
      if File.directory?(File.join(repo_root, ".jj"))
        JJ.new(repo_root: repo_root)
      elsif File.directory?(File.join(repo_root, ".git"))
        Git.new(repo_root: repo_root)
      else
        raise "No supported VCS found in #{repo_root}. Expected .jj/ or .git/ directory."
      end
    end

    class Adapter
      attr_reader :repo_root

      def initialize(repo_root:)
        @repo_root = repo_root
      end

      def add_workspace(workspace_dir, name: nil)
        raise NotImplementedError
      end

      def forget_workspace(workspace_dir)
        raise NotImplementedError
      end

      def dirty?(workspace_dir)
        raise NotImplementedError
      end

      def reset_to_latest(workspace_dir)
        raise NotImplementedError
      end

      def config_mounts
        raise NotImplementedError
      end
    end
  end
end
