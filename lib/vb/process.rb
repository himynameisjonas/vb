# frozen_string_literal: true

module VB
  class Process
    def alive?(pid:)
      ::Process.kill(0, Integer(pid))
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end
  end
end
