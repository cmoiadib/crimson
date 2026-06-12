# frozen_string_literal: true

require "open3"
require "timeout"

module Crimson
  module Tools
    module RunCommand
      TOOL_NAME = "run_command"
      EXECUTION_MODE = :sequential

      PARAMS = {
        command: { type: "string", description: "The shell command to execute" },
        timeout: { type: "integer", description: "Timeout in seconds (default: 30)" }
      }.freeze

      @update_callback = nil
      @callback_mutex = Mutex.new

      class << self
        def on_update=(callback)
          @callback_mutex.synchronize { @update_callback = callback }
        end

        def on_update
          @callback_mutex.synchronize { @update_callback }
        end
      end

      def self.definition
        Schema.build(name: TOOL_NAME, description: "Execute a shell command and return stdout and stderr.", parameters: PARAMS, required: ["command"])
      end

      def self.anthropic_definition
        Schema.build_anthropic(name: TOOL_NAME, description: "Execute a shell command and return stdout and stderr.", parameters: PARAMS, required: ["command"])
      end

      def self.call(command:, timeout: 30)
        return "Error: No command provided" if command.nil? || command.strip.empty?

        stdout = String.new
        stderr = String.new
        status = nil
        start_time = Time.now

        begin
          Timeout.timeout(timeout) do
            Open3.popen3(command) do |stdin, out, err, wait_thr|
              stdin.close

              readers = [out, err]
              while readers.any?
                ready = IO.select(readers, nil, nil, 0.1)
                next unless ready

                ready[0].each do |io|
                  chunk = io.read_nonblock(4096, exception: false)
                  if chunk == :wait_readable || chunk.nil?
                    readers.delete(io) if io.eof?
                    next
                  end
                  if io == out
                    stdout << chunk
                  else
                    stderr << chunk
                  end
                  elapsed = Time.now - start_time
                  cb = on_update
                  cb&.call(command, elapsed, stdout.length + stderr.length)
                end
              end

              status = wait_thr.value
            end
          end

          output = String.new
          output << stdout if !stdout.empty?
          output << stderr if !stderr.empty?
          output = "(no output)" if output.strip.empty?
          output << "\n(exit code: #{status.exitstatus})" unless status.success?
          output
        rescue Timeout::Error
          "Error: Command timed out after #{timeout} seconds"
        rescue => e
          "Error executing command: #{e.message}"
        end
      end
    end
  end
end
