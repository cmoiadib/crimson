require 'reline'
require 'pastel'

module Crimson
  class Repl
    def initialize(agent)
      @agent = agent
      @pastel = Pastel.new
      @tui = TUI.new
    end

    def start
      setup_tui
      setup_reline

      loop do
        input = read_input

        break if input.nil?
        input = input.strip
        break if input == "/exit" || input == "/quit"
        next if input.empty?

        if input.start_with?("/")
          handle_command(input)
        else
          @tui.render_user_input(input)
          begin
            @agent.run(input, @tui)
          rescue => e
            @tui.render_error("Error: #{e.message}")
          end
        end
      end

      @tui.cleanup
    end

    private

    def setup_tui
      @tui.setup
    end

    def setup_reline
      Reline.completion_proc = proc { |text|
        if text.start_with?("/")
          @tui.show_command_palette(text)
          TUI::COMMANDS.keys.select { |cmd| cmd.start_with?(text) }
        else
          @tui.hide_command_palette
          []
        end
      }

      Reline.completion_append_character = ""

      # Handle special keys
      Reline.pre_input_hook = proc {
        @tui.render_input_prompt
      }
    end

    def read_input
      @tui.render_input_prompt
      input = Reline.readline("", false)
      @tui.hide_command_palette
      input
    end

    def handle_command(input)
      case input
      when "/help"
        @tui.render_message(@pastel.bold("Commands:"))
        TUI::COMMANDS.each do |cmd, desc|
          @tui.render_message("  #{@pastel.bold(cmd.ljust(10))} #{desc}")
        end
      when "/clear"
        @agent.reset
        @tui.clear_output_buffer
        @tui.render_message(@pastel.dim("Conversation cleared."))
      when "/model"
        config = Crimson.config
        @tui.render_message("Provider: #{PROVIDERS[config.provider.to_sym][:name]}")
        @tui.render_message("Model: #{config.model}")
      when "/tools"
        @tui.render_message(@pastel.bold("Available tools:"))
        @agent.tool_registry.tool_names.each do |name|
          @tui.render_message("  - #{name}")
        end
      when "/save"
        result = @agent.save_history
        @tui.render_message(result)
      when "/load"
        result = @agent.load_history
        @tui.render_message(result)
      when "/usage"
        usage = @agent.token_usage
        @tui.render_message(@pastel.bold("Token usage this session:"))
        @tui.render_message("  Prompt:     #{usage[:prompt]}")
        @tui.render_message("  Completion: #{usage[:completion]}")
        @tui.render_message("  Total:      #{usage[:total]}")
      else
        @tui.render_error("Unknown command: #{input}. Type /help for available commands.")
      end
    end
  end
end
