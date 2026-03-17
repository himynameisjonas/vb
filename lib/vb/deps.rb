# frozen_string_literal: true

require "digest"

module VB
  class Deps
    LOCKFILES = {
      "Gemfile.lock" => "bundle install",
      "package-lock.json" => "npm install",
      "pnpm-lock.yaml" => "pnpm install",
      "yarn.lock" => "yarn install"
    }.freeze

    def initialize(repo_root:, workspace_dir:)
      @repo_root = repo_root
      @workspace_dir = workspace_dir
    end

    def stale_lockfiles
      LOCKFILES.keys.select { |lf| stale?(lf) }
    end

    def up_to_date?
      stale_lockfiles.empty?
    end

    def install_commands
      stale_lockfiles.map { |lf| LOCKFILES[lf] }
    end

    private

    def stale?(lockfile)
      src = File.join(@repo_root, lockfile)
      dst = File.join(@workspace_dir, lockfile)
      return false unless File.exist?(src)
      return true unless File.exist?(dst)
      Digest::SHA256.file(src).hexdigest != Digest::SHA256.file(dst).hexdigest
    end
  end
end
