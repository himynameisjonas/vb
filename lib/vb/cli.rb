# frozen_string_literal: true

require "fileutils"
require "thor"

module VB
  class CLI < Thor
    class << self
      attr_writer :pool_factory

      def pool_factory
        @pool_factory ||= ->(repo_root:) { Pool.new(repo_root: repo_root) }
      end

      attr_writer :bootstrap_factory

      def bootstrap_factory
        @bootstrap_factory ||= ->(repo_root:) { Bootstrap.new(repo_root: repo_root) }
      end
    end

    default_command :acquire

    desc "acquire", "Acquire a workspace and drop to shell"
    def acquire
      run_acquire(nil)
    end

    desc "opencode", "Acquire a workspace and launch opencode"
    def opencode
      run_acquire("opencode")
    end

    desc "claude", "Acquire a workspace and launch claude"
    def claude
      run_acquire(
        "claude --dangerously-skip-permissions",
        resume_cmd: "claude --continue --dangerously-skip-permissions"
      )
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

    desc "bootstrap", "Rebuild the vibe template image from .vibe/bootstrap.sh (--edit to open script)"
    option :edit, type: :boolean, default: false
    def bootstrap
      if options[:edit]
        run_bootstrap_edit
      else
        run_bootstrap_rebuild
      end
    end

    no_commands do
      def run_acquire(send_cmd, resume_cmd: nil)
        pool = self.class.pool_factory.call(repo_root: Dir.pwd)
        result = pool.acquire(send_cmd: send_cmd, resume_cmd: resume_cmd)
        action = result[:resumed] ? "Resuming" : "Creating"
        puts "#{action} workspace: #{result[:name]}"
      end

      def run_bootstrap_edit
        b = self.class.bootstrap_factory.call(repo_root: Dir.pwd)
        unless File.exist?(b.script_path)
          FileUtils.mkdir_p(File.dirname(b.script_path))
          content = <<~BASH
            #!/bin/bash

            # Install tools and configure the vibe VM template.
            # This script runs once to create the base disk image.
            # All workspaces will inherit from this image.

          BASH
          File.write(b.script_path, content)
          File.chmod(0o755, b.script_path)
          puts "Created #{b.script_path}"
        end
        exec(ENV.fetch("EDITOR", "vi"), b.script_path)
      end

      def run_bootstrap_rebuild
        b = self.class.bootstrap_factory.call(repo_root: Dir.pwd)
        unless File.exist?(b.script_path)
          raise Thor::Error, "No bootstrap script found. Run `vb bootstrap --edit` to create one."
        end
        pool = self.class.pool_factory.call(repo_root: Dir.pwd)
        if File.exist?(b.image_path)
          workspaces = pool.list
          unless workspaces.empty?
            puts "Found #{workspaces.length} workspace(s). They use the old template image."
            $stdout.print "Destroy all workspaces? [y/N] "
            answer = $stdin.gets.to_s.strip.downcase
            if answer == "y"
              pool.destroy_all
              puts "Destroyed #{workspaces.length} workspace(s)."
            end
          end
          FileUtils.rm(b.image_path)
        end
        puts "Bootstrapping template image..."
        b.run
        puts "Template image created at #{b.image_path}"
      end
    end
  end
end
