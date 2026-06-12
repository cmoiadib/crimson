# frozen_string_literal: true

require "io/console"
require "pastel"

module Crimson
  class StatusBar
    SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze

    def initialize(pastel)
      @pastel = pastel
      @model = ""
      @provider = ""
      @tokens = { prompt: 0, completion: 0, total: 0 }
      @cost = 0.0
      @status = :idle
      @tool_name = nil
      @spinner_idx = 0
      @mutex = Mutex.new
      @io_mutex = Mutex.new
      @stopped = false
      @input_row = 0
      @scroll_bottom = 0
      @bar_height = 3
      @resize_pending = false
    end

    def start
      enter_alternate_screen
      setup_scroll_region
      draw
      setup_signals
    end

    def stop
      return if @stopped
      @stopped = true
      leave_alternate_screen
    end

    def update(model: nil, provider: nil, tokens: nil, cost: nil, status: nil, tool_name: nil)
      @mutex.synchronize do
        @model = model if model
        @provider = provider if provider
        @tokens = tokens if tokens
        @cost = cost if cost
        @status = status if status
        @tool_name = tool_name unless tool_name == :__clear
        @tool_name = nil if tool_name == :__clear
        @spinner_idx += 1 if @status == :thinking
      end
      draw
    end

    def show_thinking
      update(status: :thinking)
    end

    def hide_thinking
      update(status: :idle)
    end

    def show_tool(name)
      update(status: :tool, tool_name: name)
    end

    def hide_tool
      update(status: :idle, tool_name: :__clear)
    end

    def write(text)
      @io_mutex.synchronize do
        $stdout.write(text)
        $stdout.flush
      end
    end

    def write_ln(text)
      write("#{text}\n")
    end

    def flush
      $stdout.flush
    end

    def write_raw(data)
      @io_mutex.synchronize do
        $stdout.write(data)
        $stdout.flush
      end
    end

    def move_to_input
      @io_mutex.synchronize do
        $stdout.write("\e[#{@input_row + 1};1H")
        $stdout.flush
      end
    end

    def handle_resize
      return unless @resize_pending
      @resize_pending = false
      setup_scroll_region
      draw
    end

    private

    def enter_alternate_screen
      @io_mutex.synchronize do
        $stdout.write("\e[?1049h")
        $stdout.flush
      end
    end

    def leave_alternate_screen
      @io_mutex.synchronize do
        $stdout.write("\e[r")
        $stdout.write("\e[?25h")
        $stdout.write("\e[?1049l")
        $stdout.flush
      end
    end

    def setup_scroll_region
      rows, = term_size
      @scroll_bottom = rows - @bar_height
      @input_row = @scroll_bottom - 1
      @io_mutex.synchronize do
        $stdout.write("\e[1;#{@scroll_bottom}r")
        $stdout.flush
      end
    end

    def draw
      @mutex.synchronize do
        bar_start = @scroll_bottom
        width = term_size[1]

        status_line = draw_status_line
        info_line = draw_info_line

        @io_mutex.synchronize do
          $stdout.write("\e7")

          $stdout.write("\e[#{bar_start + 1};1H")
          $stdout.write("\e[2K")
          $stdout.write(@pastel.dim("─" * width))

          $stdout.write("\e[#{bar_start + 2};1H")
          $stdout.write("\e[2K")
          $stdout.write(status_line)

          $stdout.write("\e[#{bar_start + 3};1H")
          $stdout.write("\e[2K")
          $stdout.write(info_line)

          $stdout.write("\e8")
          $stdout.flush
        end
      end
    end

    def draw_status_line
      parts = []

      case @status
      when :thinking
        frame = SPINNER[@spinner_idx % SPINNER.length]
        parts << @pastel.cyan(" #{frame} thinking")
      when :streaming
        parts << @pastel.cyan(" ⠹ streaming")
      when :tool
        parts << @pastel.yellow(" ⚙ #{@tool_name || 'tool'}")
      else
        parts << @pastel.dim(" ● ready")
      end

      unless @model.empty?
        parts << @pastel.bold.cyan(" #{@model}")
      end
      unless @provider.empty?
        parts << @pastel.dim(" (#{@provider})")
      end

      parts.join
    end

    def draw_info_line
      parts = []

      if @tokens[:total] > 0
        parts << @pastel.dim(" #{@tokens[:prompt]}↑ #{@tokens[:completion]}↓ = #{@tokens[:total]}")
      end

      if @cost > 0
        parts << @pastel.dim(" │ $#{format('%.4f', @cost)}")
      end

      parts.empty? ? "" : parts.join
    end

    def setup_signals
      trap("WINCH") { @resize_pending = true }
      at_exit { stop }
    end

    def term_size
      IO.console&.winsize || [24, 80]
    rescue
      [24, 80]
    end
  end
end
