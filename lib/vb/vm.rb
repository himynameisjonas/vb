# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module VB
  class VM
    def initialize(workspace_dir:, disk_image:)
      @workspace_dir = workspace_dir
      @disk_image = disk_image
    end

    def launch(send_cmd:)
      Dir.mktmpdir do |config_dir|
        populate_config(config_dir)
        run_vibe(args_for(send_cmd: send_cmd, config_dir: config_dir), chdir: @workspace_dir)
      end
    end

    def args_for(send_cmd:, config_dir:)
      parent_dir = File.dirname(@workspace_dir)
      init_cmd = build_init_cmd(send_cmd)
      [
        "--mount", "#{config_dir}:/mnt/claude-config:read-only",
        "--mount", "#{Dir.home}/.config/jj:/root/.config/jj",
        "--mount", "#{Dir.home}/.config/opencode:/root/.config/opencode",
        "--mount", "#{parent_dir}:#{parent_dir}",
        "--expect", "root@vibe",
        "--send", "TERM=xterm-256color CI=1 exec bash -l",
        "--expect", "root@vibe",
        "--send", init_cmd
      ]
    end

    private

    def populate_config(config_dir)
      claude_json = File.join(Dir.home, ".claude.json")
      FileUtils.cp(claude_json, File.join(config_dir, ".claude.json")) if File.exist?(claude_json)

      opencode_auth = File.join(Dir.home, ".local", "share", "opencode", "auth.json")
      FileUtils.cp(opencode_auth, File.join(config_dir, "opencode-auth.json")) if File.exist?(opencode_auth)
    end

    def build_init_cmd(send_cmd)
      parts = []
      parts << "cp /mnt/claude-config/.claude.json /root/.claude.json 2>/dev/null; true"
      parts << "{ mkdir -p /root/.local/share/opencode && cp /mnt/claude-config/opencode-auth.json /root/.local/share/opencode/auth.json 2>/dev/null; true; }"
      parts << "cd #{@workspace_dir}"
      parts << "{ set -a; [ -f .vibe/.env ] && source .vibe/.env; set +a; }"
      parts << "unset CI"
      parts << send_cmd if send_cmd
      parts.join(" && ")
    end

    def run_vibe(args, chdir: nil)
      opts = chdir ? {chdir: chdir} : {}
      system("vibe", *args, **opts)
    end
  end
end
