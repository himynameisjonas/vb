# frozen_string_literal: true

require "fileutils"

module VB
  class Pool
    def initialize(
      repo_root:,
      state_class: State,
      names_class: Names,
      workspace_factory: ->(workspace_dir:, repo_root:) { Workspace.new(workspace_dir: workspace_dir, repo_root: repo_root) },
      vm_factory: ->(workspace_dir:, disk_image:) { VM.new(workspace_dir: workspace_dir, disk_image: disk_image) },
      deps_factory: ->(repo_root:, workspace_dir:) { Deps.new(repo_root: repo_root, workspace_dir: workspace_dir) },
      process_factory: ->(*) { Process.new }
    )
      @repo_root = repo_root
      @state_class = state_class
      @names_class = names_class
      @workspace_factory = workspace_factory
      @vm_factory = vm_factory
      @deps_factory = deps_factory
      @process_factory = process_factory
    end

    def list
      @state_class.with_lock(repo_root: @repo_root, write: false) do |state|
        workspaces = state["workspaces"] || {}
        process = @process_factory.call

        workspaces.map do |name, info|
          ws = @workspace_factory.call(workspace_dir: info["workspace_dir"], repo_root: @repo_root)
          pid = info["pid"]
          in_use = pid ? process.alive?(pid: pid) : false
          {
            name: name,
            workspace_dir: info["workspace_dir"],
            in_use: in_use,
            dirty: ws.dirty?
          }
        end
      end
    end

    def destroy(name:)
      @state_class.with_lock(repo_root: @repo_root) do |state|
        _destroy(name: name, state: state)
      end
    end

    def destroy_all
      @state_class.with_lock(repo_root: @repo_root) do |state|
        (state["workspaces"] || {}).keys.each { |name| _destroy(name: name, state: state) }
      end
    end

    def acquire(send_cmd: "opencode")
      vm = nil
      name = nil

      @state_class.with_lock(repo_root: @repo_root) do |state|
        state["workspaces"] ||= {}
        process = @process_factory.call

        found = state["workspaces"].find do |_n, info|
          pid = info["pid"]
          not_in_use = pid.nil? || !process.alive?(pid: pid)
          ws = @workspace_factory.call(workspace_dir: info["workspace_dir"], repo_root: @repo_root)
          not_in_use && !ws.dirty?
        end

        if found
          name, info = found
          ws = @workspace_factory.call(workspace_dir: info["workspace_dir"], repo_root: @repo_root)
          ws.reset_to_latest
          info["pid"] = ::Process.pid
          vm = @vm_factory.call(workspace_dir: info["workspace_dir"], disk_image: info["disk_image"])
        else
          name = @names_class.generate
          parent_dir = File.dirname(@repo_root)
          workspace_dir = File.join(parent_dir, "#{File.basename(@repo_root)}-#{name}")
          disk_image = File.join(@repo_root, ".vibe", "instance.raw")
          ws = @workspace_factory.call(workspace_dir: workspace_dir, repo_root: @repo_root)
          ws.add
          state["workspaces"][name] = {
            "workspace_dir" => workspace_dir,
            "disk_image" => disk_image,
            "created_at" => Time.now.iso8601,
            "pid" => ::Process.pid
          }
          vm = @vm_factory.call(workspace_dir: workspace_dir, disk_image: disk_image)
        end
      end

      vm.launch(send_cmd: send_cmd)

      @state_class.with_lock(repo_root: @repo_root) do |state|
        state.dig("workspaces", name)&.delete("pid")
      end

      name
    end

    private

    def _destroy(name:, state:)
      workspaces = state["workspaces"] || {}
      info = workspaces[name]
      return unless info
      ws = @workspace_factory.call(workspace_dir: info["workspace_dir"], repo_root: @repo_root)
      ws.forget
      FileUtils.rm_rf(info["workspace_dir"])
      workspaces.delete(name)
    end
  end
end
