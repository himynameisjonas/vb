# frozen_string_literal: true

module VB
  class Process
    def in_use?(workspace_dir:)
      ps_output.include?(workspace_dir)
    end

    def in_use_dirs(workspace_dirs:)
      output = ps_output
      workspace_dirs.select { |dir| output.include?(dir) }
    end

    def alive?(pid:)
      ::Process.kill(0, Integer(pid))
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    private

    def ps_output
      `ps aux`
    end
  end
end
