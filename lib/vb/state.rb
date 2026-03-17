# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

module VB
  class State
    def self.with_lock(repo_root:, &block)
      path = state_path(repo_root)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::RDWR | File::CREAT, 0o600) do |f|
        f.flock(File::LOCK_EX)
        raw = f.read
        state = JSON.parse(raw.empty? ? "{}" : raw)
        state = heal(state, repo_root: repo_root)
        block.call(state)
        f.rewind
        f.truncate(0)
        f.write(JSON.generate(state))
      end
    end

    def self.state_path(repo_root)
      digest = Digest::SHA256.hexdigest(repo_root)[0..5]
      File.join(Dir.home, ".local", "share", "vb", digest, "state.json")
    end

    def self.heal(state, repo_root:)
      return state unless state.key?("workspaces")
      state["workspaces"].select! { |_, v| Dir.exist?(v["workspace_dir"].to_s) }
      state
    end
  end
end
