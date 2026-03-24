# frozen_string_literal: true

require "fileutils"

module VB
  class Bootstrap
    def initialize(repo_root:)
      @repo_root = repo_root
    end

    def needed?
      script_exists? && !image_exists?
    end

    def script_path
      File.join(@repo_root, ".vibe", "bootstrap.sh")
    end

    def image_path
      File.join(@repo_root, ".vibe", "instance.raw")
    end

    def run
      raise "No bootstrap script at #{script_path}" unless script_exists?

      parent_dir = File.dirname(@repo_root)
      args = [
        "--mount", "#{parent_dir}:#{parent_dir}",
        "--expect", "root@vibe",
        "--send", "TERM=xterm-256color exec bash -l",
        "--expect", "root@vibe",
        "--send", "cd #{@repo_root} && bash .vibe/bootstrap.sh"
      ]
      result = run_vibe(args, chdir: @repo_root)
      unless result
        FileUtils.rm_f(image_path)
        raise "Bootstrap failed — vibe exited with error"
      end
    end

    private

    def image_exists?
      File.exist?(image_path)
    end

    def script_exists?
      File.exist?(script_path)
    end

    def run_vibe(args, chdir: nil)
      opts = chdir ? {chdir: chdir} : {}
      system("vibe", *args, **opts)
    end
  end
end
