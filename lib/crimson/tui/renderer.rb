# frozen_string_literal: true

require "pastel"

module Crimson
  class TuiRenderer
    attr_reader :pastel, :width
    attr_accessor :show_status_bar, :show_tool_panels, :status_line

    def initialize
      @pastel = Pastel.new
      @width = terminal_width
      @mutex = Mutex.new
      @running = false
      @render_thread = nil
      @current_output = String.new
      @tool_calls = []
      @spinner_index = 0
      @spinner_frames = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]
      @show_status_bar = true
      @show_tool_panels = true
      @status_line = ""
      @last_output_length = 0
    end

    def start
      return if @running

      @running = true
      @render_thread = Thread.new { render_loop }
    end

    def stop
      @running = false
      @render_thread&.join(2)
      @render_thread = nil
    end

    def update_output(text)
      @mutex.synchronize { @current_output = text }
    end

    def append_output(text)
      @mutex.synchronize { @current_output += text }
    end

    def clear_output
      @mutex.synchronize do
        @current_output = String.new
        @last_output_length = 0
      end
    end

    def add_tool_call(tool_name, args)
      @mutex.synchronize do
        @tool_calls << { name: tool_name, args: args, active: true, result: nil, error: false }
      end
    end

    def complete_tool_call(tool_name, result, error: false)
      @mutex.synchronize do
        tc = @tool_calls.reverse.find { |t| t[:name] == tool_name && t[:active] }
        if tc
          tc[:active] = false
          tc[:result] = result
          tc[:error] = error
        end
      end
    end

    def clear_tool_calls
      @mutex.synchronize { @tool_calls.clear }
    end

    def render_now
      render_pending_output
    end

    private

    def render_loop
      while @running
        sleep 0.05
        render_pending_output
      end
    end

    def render_pending_output
      output_to_print = nil
      tool_updates = nil
      status = nil

      @mutex.synchronize do
        if @current_output.length > @last_output_length
          output_to_print = @current_output[@last_output_length..]
          @last_output_length = @current_output.length
        end
        tool_updates = render_tool_updates
        status = render_status_bar if @show_status_bar
      end

      $stdout.write(output_to_print) if output_to_print
      $stdout.write(tool_updates) if tool_updates
      $stdout.write(status) if status
      $stdout.flush
    end

    def render_tool_updates
      return nil unless @show_tool_panels
      return nil if @tool_calls.empty?

      lines = []
      @tool_calls.last(3).each do |tc|
        next if tc[:rendered]

        status_icon = tc[:active] ? spinner_frame : (tc[:error] ? @pastel.red("✗") : @pastel.green("✓"))
        name = tc[:name]
        args = tc[:args].is_a?(Hash) ? tc[:args].inspect[0..50] : tc[:args].to_s[0..50]
        lines << "\n  #{status_icon} #{@pastel.cyan(name)}(#{args})"
        tc[:rendered] = true
      end

      lines.join
    end

    def render_status_bar
      return nil if @status_line.empty?
      "\r#{@pastel.dim(@status_line.to_s.ljust(@width))}"
    end

    def spinner_frame
      frame = @spinner_frames[@spinner_index % @spinner_frames.length]
      @spinner_index += 1
      @pastel.cyan(frame)
    end

    def terminal_width
      require 'io/console'
      IO.console&.winsize&.[](1) || 80
    rescue
      80
    end
  end
end
