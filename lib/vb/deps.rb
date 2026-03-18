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
      lockfile_paths.select { |rel_path| stale?(rel_path) }
    end

    def up_to_date?
      stale_lockfiles.empty?
    end

    def install_commands
      stale_lockfiles.map { |rel_path| command_for(rel_path) }
    end

    private

    def lockfile_paths
      paths = []
      LOCKFILES.each_key do |lf|
        paths << lf if File.exist?(File.join(@repo_root, lf))
      end
      Dir.children(@repo_root).sort.each do |child|
        child_path = File.join(@repo_root, child)
        next unless File.directory?(child_path)
        next if child.start_with?(".")
        LOCKFILES.each_key do |lf|
          rel = File.join(child, lf)
          paths << rel if File.exist?(File.join(@repo_root, rel))
        end
      end
      paths
    end

    def stale?(rel_path)
      src = File.join(@repo_root, rel_path)
      dst = File.join(@workspace_dir, rel_path)
      return false unless File.exist?(src)
      return true unless File.exist?(dst)
      Digest::SHA256.file(src).hexdigest != Digest::SHA256.file(dst).hexdigest
    end

    def command_for(rel_path)
      dir = File.dirname(rel_path)
      base = File.basename(rel_path)
      cmd = LOCKFILES[base]
      (dir == ".") ? cmd : "cd #{dir} && #{cmd}"
    end
  end
end
