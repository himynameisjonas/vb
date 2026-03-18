# frozen_string_literal: true

require "thor"

module VB
  class CLI < Thor
    class << self
      attr_writer :pool_factory

      def pool_factory
        @pool_factory ||= ->(repo_root:) { Pool.new(repo_root: repo_root) }
      end
    end

    default_command :acquire

    desc "acquire", "Acquire a workspace and launch vibe (bare shell)"
    def acquire
      run_acquire("bash")
    end

    desc "opencode", "Acquire a workspace and launch opencode"
    def opencode
      run_acquire("opencode")
    end

    desc "claude", "Acquire a workspace and launch claude"
    def claude
      run_acquire("claude --dangerously-skip-permissions")
    end

    desc "status", "Show all workspaces"
    def status
      pool = self.class.pool_factory.call(repo_root: Dir.pwd)
      workspaces = pool.list
      if workspaces.empty?
        puts "No workspaces."
      else
        workspaces.each do |ws|
          use_status = ws[:in_use] ? "in-use" : "available"
          dirty_status = ws[:dirty] ? "dirty" : "clean"
          puts "#{ws[:name]}  #{ws[:workspace_dir]}  #{use_status}  #{dirty_status}"
        end
      end
    end

    no_commands do
      def run_acquire(send_cmd)
        pool = self.class.pool_factory.call(repo_root: Dir.pwd)
        name = pool.acquire(send_cmd: send_cmd)
        puts "Workspace: #{name}"
      end
    end

    desc "destroy [NAME]", "Destroy a workspace (or all with --all)"
    option :all, type: :boolean, default: false
    def destroy(name = nil)
      pool = self.class.pool_factory.call(repo_root: Dir.pwd)
      if options[:all]
        pool.destroy_all
        puts "Destroyed all workspaces."
      else
        raise Thor::Error, "Provide a name or --all" unless name
        pool.destroy(name: name)
        puts "Destroyed: #{name}"
      end
    end
  end
end
