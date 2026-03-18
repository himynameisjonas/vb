# frozen_string_literal: true

require "tmpdir"
require "fileutils"

class VB::PoolTest < TLDR
  def setup
    @repo_root = Dir.mktmpdir
    @fake_state = {}
    @fake_state_class = build_fake_state_class(@fake_state)
    @pool = VB::Pool.new(repo_root: @repo_root, state_class: @fake_state_class)
  end

  def teardown
    FileUtils.rm_rf(@repo_root)
  end

  def test_list_returns_empty_when_no_workspaces
    @fake_state["workspaces"] = {}
    result = @pool.list
    assert_equal [], result
  end

  def test_list_returns_workspace_entries
    @fake_state["workspaces"] = {
      "swift-falcon" => {"workspace_dir" => @repo_root}
    }

    fake_process = Object.new
    def fake_process.in_use_dirs(workspace_dirs:) = []
    fake_workspace = Object.new
    def fake_workspace.dirty? = false

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      process_factory: ->(*) { fake_process },
      workspace_factory: ->(**) { fake_workspace }
    )

    result = pool.list
    assert_equal 1, result.length
    assert_equal "swift-falcon", result[0][:name]
    assert_equal @repo_root, result[0][:workspace_dir]
    assert_equal false, result[0][:in_use]
    assert_equal false, result[0][:dirty]
  end

  def test_list_marks_in_use_workspace
    dir = @repo_root
    @fake_state["workspaces"] = {"brave-hawk" => {"workspace_dir" => dir, "pid" => Process.pid}}

    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| pid == Process.pid }
    fake_workspace = Object.new
    def fake_workspace.dirty? = false

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      process_factory: ->(*) { fake_process },
      workspace_factory: ->(**) { fake_workspace }
    )

    result = pool.list
    assert_equal true, result[0][:in_use]
  end

  def test_destroy_removes_workspace_from_state
    @fake_state["workspaces"] = {
      "swift-falcon" => {"workspace_dir" => @repo_root}
    }
    fake_workspace = Object.new
    def fake_workspace.forget = nil

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      workspace_factory: ->(**) { fake_workspace }
    )
    pool.destroy(name: "swift-falcon")
    refute @fake_state["workspaces"].key?("swift-falcon")
  end

  def test_destroy_calls_forget_on_workspace
    @fake_state["workspaces"] = {
      "cool-wolf" => {"workspace_dir" => @repo_root}
    }
    forget_called = false
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:forget) { forget_called = true }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      workspace_factory: ->(**) { fake_workspace }
    )
    pool.destroy(name: "cool-wolf")
    assert forget_called
  end

  def test_destroy_is_noop_for_unknown_name
    @fake_state["workspaces"] = {}
    pool = VB::Pool.new(repo_root: @repo_root, state_class: @fake_state_class)
    pool.destroy(name: "nonexistent")
    assert_equal({}, @fake_state["workspaces"])
  end

  def test_destroy_all_removes_all_workspaces
    @fake_state["workspaces"] = {
      "swift-falcon" => {"workspace_dir" => @repo_root},
      "brave-hawk" => {"workspace_dir" => @repo_root}
    }
    fake_workspace = Object.new
    def fake_workspace.forget = nil

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      workspace_factory: ->(**) { fake_workspace }
    )
    pool.destroy_all
    assert_equal({}, @fake_state["workspaces"])
  end

  def test_destroy_all_removes_all_workspaces_including_last
    @fake_state["workspaces"] = {
      "alpha" => {"workspace_dir" => @repo_root},
      "beta" => {"workspace_dir" => @repo_root},
      "gamma" => {"workspace_dir" => @repo_root}
    }
    fake_workspace = Object.new
    def fake_workspace.forget = nil

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      workspace_factory: ->(**) { fake_workspace }
    )
    pool.destroy_all
    assert_equal({}, @fake_state["workspaces"])
  end

  def test_acquire_returns_workspace_name
    fake_workspace = Object.new
    def fake_workspace.add(name: nil) = nil
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:) = nil
    fake_names_class = Class.new do
      def self.generate = "fast-gecko"
    end

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      names_class: fake_names_class,
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    @fake_state["workspaces"] = {}
    name = pool.acquire
    assert_equal "fast-gecko", name
  end

  def test_acquire_persists_workspace_to_state
    fake_workspace = Object.new
    def fake_workspace.add(name: nil) = nil
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:) = nil
    fake_names_class = Class.new do
      def self.generate = "light-crane"
    end

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      names_class: fake_names_class,
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    @fake_state["workspaces"] = {}
    pool.acquire
    assert @fake_state["workspaces"].key?("light-crane")
    assert @fake_state["workspaces"]["light-crane"].key?("workspace_dir")
  end

  def test_acquire_calls_workspace_add
    add_called = false
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:add) { |name: nil| add_called = true }
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:) = nil
    fake_names_class = Class.new do
      def self.generate = "calm-otter"
    end

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      names_class: fake_names_class,
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    @fake_state["workspaces"] = {}
    pool.acquire
    assert add_called
  end

  def test_acquire_calls_vm_launch_with_send_cmd
    launched_with = nil
    fake_workspace = Object.new
    def fake_workspace.add(name: nil) = nil
    fake_vm = Object.new
    fake_vm.define_singleton_method(:launch) { |send_cmd:| launched_with = send_cmd }
    fake_names_class = Class.new do
      def self.generate = "dark-badger"
    end

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: @fake_state_class,
      names_class: fake_names_class,
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    @fake_state["workspaces"] = {}
    pool.acquire(send_cmd: "myeditor")
    assert_equal "myeditor", launched_with
  end

  def test_acquire_writes_state_before_launching_vm
    call_log = []
    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    fake_vm.define_singleton_method(:launch) { |send_cmd:| call_log << :launch }

    state = {}
    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "test-name" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(workspace_dir:, disk_image:) do
        call_log << :state_written if state.dig("workspaces", "test-name")
        fake_vm
      end
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    pool.acquire(send_cmd: "opencode")

    assert_equal [:state_written, :launch], call_log
  end

  def test_list_shows_in_use_when_pid_is_alive
    state = {"workspaces" => {
      "swift-falcon" => {"workspace_dir" => @repo_root, "pid" => Process.pid}
    }}
    fake_workspace = Object.new
    def fake_workspace.dirty? = false
    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| pid == Process.pid }
    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      workspace_factory: ->(**) { fake_workspace },
      process_factory: ->(*) { fake_process }
    )
    result = pool.list
    assert result[0][:in_use]
  end

  def test_list_shows_available_when_pid_is_gone
    state = {"workspaces" => {
      "swift-falcon" => {"workspace_dir" => @repo_root, "pid" => 999999999}
    }}
    fake_workspace = Object.new
    def fake_workspace.dirty? = false
    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| false }
    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      workspace_factory: ->(**) { fake_workspace },
      process_factory: ->(*) { fake_process }
    )
    result = pool.list
    refute result[0][:in_use]
  end

  def test_acquire_stores_pid_in_state_then_clears_after_launch
    state = {}
    captured = {}
    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    fake_vm.define_singleton_method(:launch) do |send_cmd:|
      captured[:pid_during_launch] = state.dig("workspaces")&.values&.first&.fetch("pid", nil)
    end
    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "test-name" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    pool.acquire
    assert_equal Process.pid, captured[:pid_during_launch], "pid should be stored before launch"
    assert_nil state.dig("workspaces", "test-name", "pid"), "pid should be cleared after launch"
  end

  def test_acquire_reuses_available_workspace_instead_of_creating_new
    existing_dir = File.join(@repo_root, "existing-ws")
    state = {"workspaces" => {
      "existing-ws" => {
        "workspace_dir" => existing_dir,
        "disk_image" => "#{@repo_root}/.vibe/instance.raw"
      }
    }}

    reset_called = false
    add_called = false

    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:dirty?) { false }
    fake_workspace.define_singleton_method(:reset_to_latest) { reset_called = true }
    fake_workspace.define_singleton_method(:add) { |name: nil| add_called = true }

    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end

    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| false }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      process_factory: ->(*) { fake_process }
    )

    returned_name = pool.acquire(send_cmd: "opencode")

    assert_equal "existing-ws", returned_name, "should reuse existing workspace"
    assert reset_called, "should call reset_to_latest on reused workspace"
    refute add_called, "should NOT call add (no new workspace created)"
  end

  def test_acquire_skips_in_use_workspace_and_creates_new
    existing_dir = File.join(@repo_root, "busy-ws")
    state = {"workspaces" => {
      "busy-ws" => {
        "workspace_dir" => existing_dir,
        "disk_image" => "#{@repo_root}/.vibe/instance.raw",
        "pid" => Process.pid
      }
    }}

    add_called = false
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:dirty?) { false }
    fake_workspace.define_singleton_method(:reset_to_latest) {}
    fake_workspace.define_singleton_method(:add) { |name: nil| add_called = true }

    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end

    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| pid == Process.pid }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "fresh-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      process_factory: ->(*) { fake_process }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }

    returned_name = pool.acquire(send_cmd: "opencode")

    assert_equal "fresh-ws", returned_name, "should create new workspace when existing is in-use"
    assert add_called, "should call add for new workspace"
  end

  def test_acquire_skips_dirty_workspace_and_creates_new
    existing_dir = File.join(@repo_root, "dirty-ws")
    state = {"workspaces" => {
      "dirty-ws" => {
        "workspace_dir" => existing_dir,
        "disk_image" => "#{@repo_root}/.vibe/instance.raw"
      }
    }}

    add_called = false
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:dirty?) { true }
    fake_workspace.define_singleton_method(:reset_to_latest) {}
    fake_workspace.define_singleton_method(:add) { |name: nil| add_called = true }

    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end

    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| false }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "clean-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      process_factory: ->(*) { fake_process }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }

    returned_name = pool.acquire(send_cmd: "opencode")

    assert_equal "clean-ws", returned_name
    assert add_called
  end

  def test_acquire_avoids_name_collision
    state = {
      "workspaces" => {
        "first-name" => {
          "workspace_dir" => "/tmp/ws1",
          "disk_image" => "/tmp/d1",
          "pid" => Process.pid
        }
      }
    }

    call_count = 0
    fake_names = Class.new do
      define_singleton_method(:generate) do
        call_count += 1
        (call_count == 1) ? "first-name" : "second-name"
      end
    end

    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end
    fake_process = Object.new
    fake_process.define_singleton_method(:alive?) { |pid:| pid == Process.pid }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: fake_names,
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      process_factory: ->(*) { fake_process },
      deps_factory: ->(**) { Object.new.tap { |o| def o.install_commands = [] } }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }

    name = pool.acquire
    assert_equal "second-name", name
  end

  def test_acquire_copies_disk_image_to_workspace
    state = {}
    copied = {}
    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "test-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      deps_factory: ->(**) { Object.new.tap { |o| def o.install_commands = [] } }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst|
      copied[:src] = src
      copied[:dst] = dst
    }

    pool.acquire
    assert_equal File.join(@repo_root, ".vibe", "instance.raw"), copied[:src]
    assert copied[:dst].include?("test-ws"), "dst should be in workspace dir"
    assert copied[:dst].end_with?(".vibe/instance.raw")
    assert state["workspaces"]["test-ws"]["disk_image"].include?("test-ws")
  end

  def test_acquire_prepends_dep_install_commands_to_send_cmd
    state = {}
    launched_cmd = nil
    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    fake_vm.define_singleton_method(:launch) { |send_cmd:| launched_cmd = send_cmd }
    fake_deps = Object.new
    fake_deps.define_singleton_method(:install_commands) { ["bundle install", "cd ember_app && pnpm install"] }

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "dep-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      deps_factory: ->(**) { fake_deps }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }

    pool.acquire(send_cmd: "opencode")
    assert_equal "bundle install && cd ember_app && pnpm install && opencode", launched_cmd
  end

  def test_acquire_does_not_modify_send_cmd_when_deps_up_to_date
    state = {}
    launched_cmd = nil
    fake_workspace = Object.new
    def fake_workspace.add(name: nil)
    end
    fake_vm = Object.new
    fake_vm.define_singleton_method(:launch) { |send_cmd:| launched_cmd = send_cmd }
    fake_deps = Object.new
    def fake_deps.install_commands = []

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "clean-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      deps_factory: ->(**) { fake_deps }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }

    pool.acquire(send_cmd: "opencode")
    assert_equal "opencode", launched_cmd
  end

  def test_acquire_calls_add_before_copy_disk
    call_log = []
    state = {}
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:add) { |name: nil| call_log << :add }
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end
    fake_deps = Object.new
    def fake_deps.install_commands = []

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "order-ws" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      deps_factory: ->(**) { fake_deps }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| call_log << :copy_disk }

    pool.acquire
    assert_equal [:add, :copy_disk], call_log,
      "jj workspace add must run before copy_disk — jj creates the directory, then we copy into it"
  end

  def test_acquire_passes_name_to_workspace_add
    state = {}
    add_args = nil
    fake_workspace = Object.new
    fake_workspace.define_singleton_method(:add) { |name: nil| add_args = {name: name} }
    fake_workspace.define_singleton_method(:dirty?) { false }
    fake_vm = Object.new
    def fake_vm.launch(send_cmd:)
    end
    fake_deps = Object.new
    def fake_deps.install_commands = []

    pool = VB::Pool.new(
      repo_root: @repo_root,
      state_class: build_fake_state_class(state),
      names_class: Class.new { def self.generate = "cool-owl" },
      workspace_factory: ->(**) { fake_workspace },
      vm_factory: ->(**) { fake_vm },
      deps_factory: ->(**) { fake_deps }
    )
    pool.define_singleton_method(:copy_disk) { |src, dst| }
    pool.define_singleton_method(:copy_repo_configs) { |dir| }

    pool.acquire
    assert_equal "cool-owl", add_args[:name]
  end

  private

  def build_fake_state_class(state)
    Class.new do
      define_singleton_method(:with_lock) { |repo_root:, write: true, &block| block.call(state) }
    end
  end
end
