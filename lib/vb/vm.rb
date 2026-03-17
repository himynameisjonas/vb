# frozen_string_literal: true

require "tmpdir"

module VB
  class VM
    def initialize(workspace_dir:, disk_image:)
      @workspace_dir = workspace_dir
      @disk_image = disk_image
    end

    def launch(send_cmd:)
      Dir.mktmpdir do |config_dir|
        run_vibe(args_for(send_cmd: send_cmd, config_dir: config_dir))
      end
    end

    def args_for(send_cmd:, config_dir:)
      parent_dir = File.dirname(@workspace_dir)
      [
        "--mount", "#{config_dir}:/mnt/claude-config:read-only",
        "--mount", "#{Dir.home}/.config/jj:/root/.config/jj",
        "--mount", "#{Dir.home}/.config/opencode:/root/.config/opencode",
        "--mount", "#{parent_dir}:#{parent_dir}",
        "--expect", "root@vibe",
        "--send", "CI=1 exec bash -l",
        "--expect", "root@vibe",
        "--send", send_cmd
      ]
    end

    private

    def run_vibe(args)
      system("vibe", *args)
    end
  end
end
