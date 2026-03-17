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

    desc "acquire", "Acquire a workspace and launch vibe"
    def acquire
      pool = self.class.pool_factory.call(repo_root: Dir.pwd)
      name = pool.acquire(send_cmd: "opencode")
      puts "Workspace: #{name}"
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
