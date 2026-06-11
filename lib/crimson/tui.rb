require 'pastel'
require 'tty-screen'

module Crimson
  class TUI
    COMMANDS = {
      "/help"  => "Show help message",
      "/clear" => "Clear conversation history",
      "/model" => "Show current model",
      "/tools" => "List available tools",
      "/save"  => "Save conversation to file",
      "/load"  => "Load conversation from file",
      "/usage" => "Show token usage",
      "/exit"  => "Exit crimson"
    }.freeze

    def initialize
      @pastel = Pastel.new
      @output_buffer = []
      @input_row = 0
      @palette_visible = false
      @palette_items = []
    end

    def setup
      @height, @width = TTY::Screen.size
      @input_row = @height - 1
      $stdout.write("\e[?25l")  # Hide cursor during setup
      clear_screen
      render_border
      move_to_input
      $stdout.write("\e[?25h")  # Show cursor
      $stdout.flush
    end

    def cleanup
      move_to(@height, 0)
      $stdout.write("\e[0m")  # Reset colors
      $stdout.flush
    end

    def clear_screen
      $stdout.write("\e[2J")   # Clear entire screen
      $stdout.write("\e[H")    # Move cursor home
      $stdout.flush
    end

    def clear_output_area
      # Clear from row 2 (below border) to input_row - 1
      (2...(@input_row - 1)).each do |row|
        move_to(row, 0)
        $stdout.write("\e[2K")  # Clear line
      end
      $stdout.flush
    end

    def render_border
      # Top border with title
      move_to(1, 0)
      title = " Crimson v#{Crimson::VERSION} "
      border_width = @width - 2
      left_pad = (border_width - title.length) / 2
      right_pad = border_width - title.length - left_pad

      $stdout.write(@pastel.dim("╭"))
      $stdout.write(@pastel.dim("─" * left_pad))
      $stdout.write(@pastel.bold(title))
      $stdout.write(@pastel.dim("─" * right_pad))
      $stdout.write(@pastel.dim("╮"))
      $stdout.write("\e[K")  # Clear rest of line

      # Bottom border
      move_to(@input_row - 1, 0)
      $stdout.write(@pastel.dim("╰"))
      $stdout.write(@pastel.dim("─" * (@width - 2)))
      $stdout.write(@pastel.dim("╯"))
      $stdout.write("\e[K")

      $stdout.flush
    end

    def move_to(row, col)
      $stdout.write("\e[#{row};#{col}H")
    end

    def move_to_input
      move_to(@input_row, 0)
    end

    def render_user_input(text)
      @output_buffer << { type: :user, text: text }
      redraw_output
    end

    def render_agent_text(text)
      @output_buffer << { type: :agent, text: text }
      redraw_output
    end

    def render_tool_call(name, path = nil)
      @output_buffer << { type: :tool_call, name: name, path: path }
      redraw_output
    end

    def render_tool_result(result)
      @output_buffer << { type: :tool_result, text: result }
      redraw_output
    end

    def render_error(text)
      @output_buffer << { type: :error, text: text }
      redraw_output
    end

    def render_usage(prompt, completion, total)
      @output_buffer << { type: :usage, prompt: prompt, completion: completion, total: total }
      redraw_output
    end

    def render_message(text)
      @output_buffer << { type: :message, text: text }
      redraw_output
    end

    def render_streaming(text)
      # Find last agent message or create new one
      if @output_buffer.last && @output_buffer.last[:type] == :streaming
        @output_buffer.last[:text] << text
      else
        @output_buffer << { type: :streaming, text: text }
      end
      redraw_output
    end

    def redraw_output
      # Save cursor position
      $stdout.write("\e[s")

      # Calculate visible area (rows 2 to input_row-2)
      visible_height = @input_row - 3
      start_row = 2

      # Get lines to display
      lines = format_output_buffer

      # Show only the last N lines that fit
      visible_lines = lines.last(visible_height)
      visible_lines ||= []

      # Clear output area
      (start_row...(@input_row - 1)).each do |row|
        move_to(row, 0)
        $stdout.write("\e[2K")
      end

      # Render visible lines
      visible_lines.each_with_index do |line, idx|
        move_to(start_row + idx, 0)
        $stdout.write(line)
      end

      # Restore cursor position
      $stdout.write("\e[u")
      $stdout.flush
    end

    def format_output_buffer
      lines = []
      @output_buffer.each do |item|
        case item[:type]
        when :user
          lines << "  #{@pastel.cyan('⏺')} #{@pastel.bold(item[:text])}"
        when :agent
          wrapped = word_wrap("    #{item[:text]}", @width - 4)
          lines.concat(wrapped)
        when :streaming
          wrapped = word_wrap("    #{item[:text]}", @width - 4)
          lines.concat(wrapped)
        when :tool_call
          if item[:path]
            lines << "  #{@pastel.cyan('⏺')} #{@pastel.bold(item[:name])}(#{@pastel.red(item[:path])})"
          else
            lines << "  #{@pastel.cyan('⏺')} #{@pastel.bold(item[:name])}"
          end
        when :tool_result
          wrapped = word_wrap("    #{@pastel.dim(item[:text])}", @width - 4)
          lines.concat(wrapped)
        when :error
          wrapped = word_wrap("    #{@pastel.red(item[:text])}", @width - 4)
          lines.concat(wrapped)
        when :usage
          lines << "    #{@pastel.dim("tokens: #{item[:prompt]} prompt + #{item[:completion]} completion = #{item[:total]} total")}"
        when :message
          wrapped = word_wrap("    #{item[:text]}", @width - 4)
          lines.concat(wrapped)
        end
      end
      lines
    end

    def word_wrap(text, max_width)
      return [""] if text.nil? || text.empty?

      lines = []
      current_line = ""

      text.each_char do |char|
        if char == "\n"
          lines << current_line
          current_line = ""
        elsif current_line.length >= max_width
          lines << current_line
          current_line = char
        else
          current_line << char
        end
      end
      lines << current_line unless current_line.empty?
      lines
    end

    def show_command_palette(input_text)
      @palette_visible = true
      @palette_items = matching_commands(input_text)

      return hide_command_palette if @palette_items.empty?

      # Calculate palette position (above bottom border)
      palette_row = @input_row - 2 - @palette_items.length
      palette_row = 2 if palette_row < 2

      # Save cursor
      $stdout.write("\e[s")

      # Render palette box
      max_cmd_length = @palette_items.map { |cmd| cmd.length }.max || 0
      box_width = [@width - 4, max_cmd_length + 20].min

      move_to(palette_row, 2)
      $stdout.write(@pastel.dim("┌#{"─" * (box_width - 2)}┐"))

      @palette_items.each_with_index do |cmd, idx|
        move_to(palette_row + 1 + idx, 2)
        description = COMMANDS[cmd] || ""
        cmd_display = cmd.ljust(max_cmd_length + 2)
        desc_display = description[0...(box_width - max_cmd_length - 6)]
        $stdout.write(@pastel.dim("│ #{@pastel.bold(cmd_display)} #{desc_display.ljust(box_width - max_cmd_length - 6)} │"))
      end

      move_to(palette_row + @palette_items.length, 2)
      $stdout.write(@pastel.dim("└#{"─" * (box_width - 2)}┘"))

      # Restore cursor
      $stdout.write("\e[u")
      $stdout.flush
    end

    def hide_command_palette
      return unless @palette_visible

      @palette_visible = false

      # Save cursor
      $stdout.write("\e[s")

      # Clear palette area (estimate max height)
      max_palette_height = COMMANDS.length + 2
      palette_row = @input_row - 2 - max_palette_height
      palette_row = 2 if palette_row < 2

      (palette_row...(@input_row - 1)).each do |row|
        move_to(row, 0)
        $stdout.write("\e[2K")
      end

      # Redraw output to restore the area
      redraw_output

      # Restore cursor
      $stdout.write("\e[u")
      $stdout.flush
    end

    def matching_commands(input)
      return COMMANDS.keys if input == "/" || input == "/"

      prefix = input.downcase
      COMMANDS.keys.select { |cmd| cmd.downcase.start_with?(prefix) }
    end

    def render_input_prompt(prompt = "> ")
      move_to_input
      $stdout.write("\e[2K")  # Clear line
      $stdout.write(prompt)
      $stdout.flush
    end

    def clear_output_buffer
      @output_buffer.clear
      redraw_output
    end
  end
end
