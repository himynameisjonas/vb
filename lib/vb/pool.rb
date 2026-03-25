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
      process_factory: ->(*) { Process.new },
      bootstrap_factory: ->(repo_root:) { Bootstrap.new(repo_root: repo_root) }
    )
      @repo_root = repo_root
      @state_class = state_class
      @names_class = names_class
      @workspace_factory = workspace_factory
      @vm_factory = vm_factory
      @deps_factory = deps_factory
      @process_factory = process_factory
      @bootstrap_factory = bootstrap_factory
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

    def acquire(send_cmd: "opencode", resume_cmd: nil)
      ensure_source_image!
      vm = nil
      name = nil
      workspace_dir = nil
      resumed = false

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
          workspace_dir = info["workspace_dir"]
          ws = @workspace_factory.call(workspace_dir: workspace_dir, repo_root: @repo_root)
          ws.reset_to_latest
          info["pid"] = ::Process.pid
          vm = @vm_factory.call(workspace_dir: workspace_dir, disk_image: info["disk_image"])
          resumed = true
        else
          name = @names_class.generate
          name = @names_class.generate while state["workspaces"].key?(name)
          parent_dir = File.dirname(@repo_root)
          workspace_dir = File.join(parent_dir, "#{File.basename(@repo_root)}-#{name}")

          ws = @workspace_factory.call(workspace_dir: workspace_dir, repo_root: @repo_root)
          ws.add(name: name)

          src_disk = File.join(@repo_root, ".vibe", "instance.raw")
          dst_dir = File.join(workspace_dir, ".vibe")
          dst_disk = File.join(dst_dir, "instance.raw")
          FileUtils.mkdir_p(dst_dir)
          copy_disk(src_disk, dst_disk)
          copy_repo_configs(workspace_dir)
          state["workspaces"][name] = {
            "workspace_dir" => workspace_dir,
            "disk_image" => dst_disk,
            "created_at" => Time.now.iso8601,
            "pid" => ::Process.pid
          }
          vm = @vm_factory.call(workspace_dir: workspace_dir, disk_image: dst_disk)
        end
      end

      deps = @deps_factory.call(repo_root: @repo_root, workspace_dir: workspace_dir)
      cmds = deps.install_commands
      effective_cmd = (resumed && resume_cmd) ? resume_cmd : send_cmd
      effective_cmd = [*cmds, effective_cmd].compact.join(" && ")

      vm.launch(send_cmd: effective_cmd)

      @state_class.with_lock(repo_root: @repo_root) do |state|
        state.dig("workspaces", name)&.delete("pid")
      end

      {name: name, resumed: resumed}
    end

    private

    def ensure_source_image!
      src = File.join(@repo_root, ".vibe", "instance.raw")
      return if File.exist?(src)

      bootstrap = @bootstrap_factory.call(repo_root: @repo_root)
      if File.exist?(bootstrap.script_path)
        bootstrap.run
      else
        raise "No disk image found at #{src}. Create a bootstrap script with `vb bootstrap edit` or add one manually."
      end
    end

    def copy_disk(src, dst)
      system("cp", "-c", src, dst)
    end

    def copy_repo_configs(workspace_dir)
      src = File.join(@repo_root, ".claude", "settings.local.json")
      if File.exist?(src)
        dst_dir = File.join(workspace_dir, ".claude")
        FileUtils.mkdir_p(dst_dir)
        FileUtils.cp(src, File.join(dst_dir, "settings.local.json"))
      end

      src = File.join(@repo_root, ".env.development")
      FileUtils.cp(src, File.join(workspace_dir, ".env.development")) if File.exist?(src)
    end

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
