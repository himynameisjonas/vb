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

    def global_script_path
      File.join(Dir.home, ".vb", "bootstrap.sh")
    end

    def run
      raise "No bootstrap script at #{script_path}" unless script_exists?

      lock_path = File.join(@repo_root, ".vibe", ".bootstrap.lock")
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
        lock.flock(File::LOCK_EX)
        next if image_exists?

        parent_dir = File.dirname(@repo_root)
        global_dir = File.join(Dir.home, ".vb")

        args = [
          "--mount", "#{parent_dir}:#{parent_dir}"
        ]

        send_parts = ["cd #{@repo_root}"]

        if global_script_exists?
          args += ["--mount", "#{global_dir}:/mnt/vb-global:ro"]
          send_parts << "bash /mnt/vb-global/bootstrap.sh"
        end

        send_parts << "bash .vibe/bootstrap.sh"

        args += [
          "--expect", "root@vibe",
          "--send", "TERM=xterm-256color exec bash -l",
          "--expect", "root@vibe",
          "--send", send_parts.join(" && ")
        ]
        result = run_vibe(args, chdir: @repo_root)
        unless result
          FileUtils.rm_f(image_path)
          raise "Bootstrap failed — vibe exited with error"
        end
      end
    end

    private

    def image_exists?
      File.exist?(image_path)
    end

    def script_exists?
      File.exist?(script_path)
    end

    def global_script_exists?
      File.exist?(global_script_path)
    end

    def run_vibe(args, chdir: nil)
      opts = chdir ? {chdir: chdir} : {}
      system("vibe", *args, **opts)
    end
  end
end
