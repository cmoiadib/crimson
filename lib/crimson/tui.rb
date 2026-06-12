# frozen_string_literal: true

require "ratatui_ruby"

module Crimson
  class Tui
    SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"].freeze

    def initialize
      @messages = []
      @tool_calls = []
      @status = "idle"
      @model = ""
      @provider = ""
      @tokens = { prompt: 0, completion: 0, total: 0 }
      @cost = 0.0
      @cwd = Dir.pwd
      @session_name = ""
      @thinking_level = ""
      @loading = false
      @loading_text = "Thinking..."
      @spinner_index = 0
      @mutex = Mutex.new
      @tui = nil
      @thread = nil
      @running = false
    end

    def start
      @running = true
      @thread = Thread.new { run_tui }
      sleep 0.1 # Give TUI time to start
    end

    def stop
      @running = false
      @thread&.join(5)
      @thread = nil
    end

    def update_status(model: nil, provider: nil, tokens: nil, cost: nil, status: nil,
                      cwd: nil, session_name: nil, thinking_level: nil)
      @mutex.synchronize do
        @model = model if model
        @provider = provider if provider
        @tokens = tokens if tokens
        @cost = cost if cost
        @status = status if status
        @cwd = cwd if cwd
        @session_name = session_name if session_name
        @thinking_level = thinking_level if thinking_level
      end
    end

    def add_message(role, content)
      @mutex.synchronize do
        @messages << { role: role, content: content, timestamp: Time.now }
        # Keep last 100 messages for display
        @messages = @messages.last(100)
      end
    end

    def append_to_last_message(content)
      @mutex.synchronize do
        if @messages.any? && @messages.last[:role] == :assistant
          @messages.last[:content] += content
        else
          @messages << { role: :assistant, content: content, timestamp: Time.now }
        end
      end
    end

    def add_tool_call(name, args = {})
      @mutex.synchronize do
        @tool_calls << { name: name, args: args, status: :running, result: nil }
      end
    end

    def complete_tool_call(name, result, is_error: false)
      @mutex.synchronize do
        tc = @tool_calls.reverse.find { |t| t[:name] == name && t[:status] == :running }
        if tc
          tc[:status] = is_error ? :error : :success
          tc[:result] = result
        end
      end
    end

    def clear
      @mutex.synchronize do
        @messages.clear
        @tool_calls.clear
      end
    end

    def show_loading(text = "Thinking...")
      @mutex.synchronize do
        @loading = true
        @loading_text = text
      end
    end

    def hide_loading
      @mutex.synchronize do
        @loading = false
      end
    end

    private

    def run_tui
      RatatuiRuby.run do |tui|
        @tui = tui

        while @running
          # Check for input (non-blocking)
          event = tui.poll_event
          case event
          in { type: :key, code: "c", modifiers: ["ctrl"] }
            # Ctrl+C - could be used for cancel
          else
            nil
          end

          # Render
          tui.draw do |frame|
            render_frame(tui, frame)
          end

          sleep 0.05 # 20fps
        end
      end
    rescue => e
      # If TUI fails, log and continue
      $stderr.puts "TUI error: #{e.message}"
    end

    def render_frame(tui, frame)
      # Create layout: main content + status bar
      layout = tui.layout(
        direction: :vertical,
        constraints: [
          tui.constraint(:min, 0),      # Main content
          tui.constraint(:length, 3),   # Status bar
        ]
      )

      main_area = layout[0]
      status_area = layout[1]

      # Render main content
      render_main_content(tui, frame, main_area)

      # Render status bar
      render_status_bar(tui, frame, status_area)
    end

    def render_main_content(tui, frame, area)
      content = []

      @mutex.synchronize do
        # Messages
        @messages.each do |msg|
          case msg[:role]
          when :user
            content << tui.line(
              tui.span("❯ ", fg: "cyan"),
              tui.span(msg[:content], fg: "white", modifier: "bold")
            )
          when :assistant
            # Split long content into lines
            msg[:content].split("\n").each do |line|
              content << tui.line(tui.span(line, fg: "white"))
            end
          when :error
            content << tui.line(tui.span("✗ #{msg[:content]}", fg: "red"))
          end
        end

        # Tool calls
        @tool_calls.each do |tc|
          status_icon = case tc[:status]
                       when :running then "⠋"
                       when :success then "✓"
                       when :error then "✗"
                       end
          status_color = case tc[:status]
                        when :running then "cyan"
                        when :success then "green"
                        when :error then "red"
                        end

          args_str = tc[:args].is_a?(Hash) ? tc[:args].inspect[0..60] : tc[:args].to_s[0..60]
          content << tui.line(
            tui.span("  #{status_icon} ", fg: status_color),
            tui.span(tc[:name], fg: "cyan", modifier: "bold"),
            tui.span("(#{args_str})", fg: "white")
          )

          # Show result if completed and not too long
          if tc[:result] && tc[:status] != :running
            result_str = tc[:result].to_s[0..100]
            result_str += "..." if tc[:result].to_s.length > 100
            content << tui.line(
              tui.span("    → ", fg: "white"),
              tui.span(result_str, fg: "white")
            )
          end
        end

        # Loading spinner
        if @loading
          frame_idx = @spinner_index % SPINNER_FRAMES.length
          @spinner_index += 1
          content << tui.line(
            tui.span("  #{SPINNER_FRAMES[frame_idx]} ", fg: "cyan"),
            tui.span(@loading_text, fg: "white")
          )
        end
      end

      # Create paragraph widget
      paragraph = tui.paragraph(
        text: content,
        block: tui.block(
          title: "Crimson",
          borders: [:all],
          border_style: { fg: "cyan" }
        ),
        wrap: { trim: false }
      )

      frame.render_widget(paragraph, area)
    end

    def render_status_bar(tui, frame, area)
      left_parts = []
      right_parts = []

      @mutex.synchronize do
        # Status indicator
        case @status
        when "thinking"
          left_parts << tui.span(" thinking... ", fg: "yellow")
        when "streaming"
          left_parts << tui.span(" streaming... ", fg: "cyan")
        when "tool_running"
          left_parts << tui.span(" tool running ", fg: "magenta")
        else
          left_parts << tui.span(" idle ", fg: "white")
        end

        # Tokens
        if @tokens[:total] > 0
          left_parts << tui.span(" #{@tokens[:total]}t ", fg: "white")
        end

        # Cost
        if @cost > 0
          left_parts << tui.span(" $#{format('%.2f', @cost)} ", fg: "white")
        end

        # Model on right
        right_parts << tui.span(" #{@model} ", fg: "cyan") unless @model.empty?
        unless @thinking_level.empty? || @thinking_level == "off"
          right_parts << tui.span(" #{@thinking_level} ", fg: "yellow")
        end
      end

      # Create status line
      status_line = tui.line(*(left_parts + right_parts))

      # Render status bar
      paragraph = tui.paragraph(
        text: status_line,
        block: tui.block(
          borders: [:top],
          border_style: { fg: "cyan" }
        )
      )

      frame.render_widget(paragraph, area)
    end
  end
end
