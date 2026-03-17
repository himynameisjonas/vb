# frozen_string_literal: true

class VB::VMTest < TLDR
  def setup
    @vm = VB::VM.new(
      workspace_dir: "/repos/myrepo-swift-falcon",
      disk_image: "/repos/myrepo/.vibe/instance.raw"
    )
  end

  def test_args_includes_config_mount
    args = @vm.args_for(send_cmd: "echo hi", config_dir: "/tmp/cfg")
    assert_includes args, "--mount"
    assert args.any? { |a| a.include?("/tmp/cfg") && a.include?(":/mnt/claude-config:read-only") }
  end

  def test_args_includes_jj_config_mount
    args = @vm.args_for(send_cmd: "echo hi", config_dir: "/tmp/cfg")
    assert args.any? { |a| a.include?(".config/jj") }
  end

  def test_args_includes_parent_dir_mount
    args = @vm.args_for(send_cmd: "echo hi", config_dir: "/tmp/cfg")
    assert args.any? { |a| a.include?("/repos:/repos") }
  end

  def test_args_includes_expect_and_send_pairs
    args = @vm.args_for(send_cmd: "my_cmd", config_dir: "/tmp/cfg")
    expect_indices = args.each_index.select { |i| args[i] == "--expect" }
    send_indices = args.each_index.select { |i| args[i] == "--send" }
    assert_equal 2, expect_indices.length
    assert_equal 2, send_indices.length
    last_send_idx = send_indices.last
    assert_equal "my_cmd", args[last_send_idx + 1]
  end

  def test_args_first_send_is_bash_login
    args = @vm.args_for(send_cmd: "my_cmd", config_dir: "/tmp/cfg")
    send_indices = args.each_index.select { |i| args[i] == "--send" }
    first_send_idx = send_indices.first
    assert_includes args[first_send_idx + 1], "bash"
  end

  def test_launch_calls_run_vibe
    vibe_args = nil
    @vm.define_singleton_method(:run_vibe) { |args| vibe_args = args }
    @vm.launch(send_cmd: "opencode")
    assert_equal Array, vibe_args.class
    assert vibe_args.any? { |a| a.include?("opencode") }
  end

  def test_launch_cleans_up_tmpdir
    captured_config_dir = nil
    @vm.define_singleton_method(:run_vibe) do |args|
      mount_arg = args.find { |a| a.include?(":/mnt/claude-config:read-only") }
      captured_config_dir = mount_arg.split(":").first
    end
    @vm.launch(send_cmd: "test")
    refute Dir.exist?(captured_config_dir), "Temp dir should be cleaned up after launch"
  end
end
