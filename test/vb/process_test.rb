# frozen_string_literal: true

class VB::ProcessTest < TLDR
  def test_alive_returns_true_for_current_process
    assert VB::Process.new.alive?(pid: Process.pid)
  end

  def test_alive_returns_false_for_dead_pid
    refute VB::Process.new.alive?(pid: 999999999)
  end
end
