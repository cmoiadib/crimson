# frozen_string_literal: true

require "ratatui_ruby"

module Crimson
  class Tui
    SPINNER_FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
    VP_HEIGHT = 2

    attr_reader :input, :cursor_pos, :history_idx, :loading

    def initialize
      @input = String.new
      @cursor_pos = 0
      @history = []
      @history_idx = -1
      @history_stash = nil
      @model = ""
      @tokens = { prompt: 0, completion: 0, total: 0 }
      @cost = 0.0
      @status = :idle
      @loading = false
      @loading_text = "Thinking..."
      @spinner_idx = 0
      @spinner_last = Time.now
      @mutex = Mutex.new
      @tui = nil
    end

    def start
      RatatuiRuby.init_terminal(focus_events: false, bracketed_paste: false, viewport: :inline, height: VP_HEIGHT)
      draw_frame
    end

    def stop
      RatatuiRuby.restore_terminal if RatatuiRuby.terminal_active?
    end

    def poll_event(timeout: 0.016)
      RatatuiRuby.poll_event(timeout: timeout)
    end

    def handle_key(event)
      code = event.code
      mods = event.modifiers || []

      if event.ctrl?
        case code
        when "c"
          return :cancel
        when "u"
          @input.clear
          @cursor_pos = 0
        end
      elsif event.paste?
        event.content.to_s.each_char { |c| insert_char(c) }
      elsif code == "backspace" || code == "delete"
        if @cursor_pos > 0
          @input = @input[0...(@cursor_pos - 1)] + @input[@cursor_pos..]
          @cursor_pos -= 1
        end
      elsif code == "enter"
        text = @input.strip
        return nil if text.empty?
        @input.clear
        @cursor_pos = 0
        if text.start_with?("/")
          return { command: text }
        end
        @history << text
        @history_idx = -1
        @history_stash = nil
        return { input: text }
      elsif code == "left"
        @cursor_pos = [@cursor_pos - 1, 0].max
      elsif code == "right"
        @cursor_pos = [@cursor_pos + 1, @input.length].min
      elsif code == "up"
        navigate_history(-1)
      elsif code == "down"
        navigate_history(1)
      elsif code == "home"
        @cursor_pos = 0
      elsif code == "end"
        @cursor_pos = @input.length
      elsif event.paste?
        event.content.to_s.each_char { |c| insert_char(c) }
      elsif code.length == 1 && !event.ctrl? && !event.alt?
        insert_char(code)
      end

      nil
    end

    def insert_content(text)
      return if text.nil? || text.strip.empty?

      @mutex.synchronize do
        width = RatatuiRuby.viewport_size.width rescue 80
        inner_width = [width - 4, 10].max
        lines = text.split("\n")
        total_lines = lines.sum { |l| [l.length / inner_width + 1, 1].max }
        height = [total_lines, 20].min

        widget = RatatuiRuby::Widgets::Paragraph.new(
          text: text,
          wrap: true
        )
        RatatuiRuby.insert_before(height, widget)
        draw_frame
      end
    rescue => e
      nil
    end

    def update_status(model: nil, tokens: nil, cost: nil, status: nil)
      @mutex.synchronize do
        @model = model if model
        @tokens = tokens if tokens
        @cost = cost if cost
        @status = status if status
      end
    end

    def show_loading(text = "Thinking...")
      @mutex.synchronize do
        @loading = true
        @loading_text = text
      end
    end

    def hide_loading
      @mutex.synchronize { @loading = false }
    end

    def draw_frame
      @mutex.synchronize do
        RatatuiRuby.draw do |frame|
          area = frame.area
          status_area = RatatuiRuby::Layout::Rect.new(x: 0, y: 0, width: area.width, height: 1)
          input_area = RatatuiRuby::Layout::Rect.new(x: 0, y: 1, width: area.width, height: 1)

          frame.render_widget(build_status_line, status_area)
          frame.render_widget(build_input_line, input_area)
          frame.set_cursor_position(2 + @cursor_pos, 1)
        end
      end
    rescue => e
      nil
    end

    private

    def insert_char(c)
      @input = @input[0...@cursor_pos] + c + @input[@cursor_pos..]
      @cursor_pos += 1
    end

    def navigate_history(dir)
      return if @history.empty?

      if dir == -1
        if @history_idx == -1
          @history_stash = @input.dup
          @history_idx = @history.length - 1
        elsif @history_idx > 0
          @history_idx -= 1
        end
      elsif dir == 1
        if @history_idx >= 0
          if @history_idx >= @history.length - 1
            @history_idx = -1
            @input = @history_stash || String.new
            @cursor_pos = @input.length
            return
          else
            @history_idx += 1
          end
        end
      end

      if @history_idx >= 0
        @input = @history[@history_idx].dup
        @cursor_pos = @input.length
      end
    end

    def build_status_line
      left = []
      right = []

      case @status
      when :thinking
        now = Time.now
        if now - @spinner_last > 0.1
          @spinner_idx = (@spinner_idx + 1) % SPINNER_FRAMES.length
          @spinner_last = now
        end
        left << RatatuiRuby::Text::Span.new(content: " #{SPINNER_FRAMES[@spinner_idx]} thinking ", style: RatatuiRuby::Style::Style.new(fg: :cyan))
      when :streaming
        left << RatatuiRuby::Text::Span.new(content: " streaming ", style: RatatuiRuby::Style::Style.new(fg: :cyan))
      when :tool_running
        left << RatatuiRuby::Text::Span.new(content: " tool running ", style: RatatuiRuby::Style::Style.new(fg: :yellow))
      else
        left << RatatuiRuby::Text::Span.new(content: " ready ", style: RatatuiRuby::Style::Style.new(fg: :dark_gray))
      end

      if @tokens[:total] > 0
        left << RatatuiRuby::Text::Span.new(content: " #{@tokens[:total]}t ", style: RatatuiRuby::Style::Style.new(fg: :dark_gray))
      end

      if @cost > 0
        left << RatatuiRuby::Text::Span.new(content: " $#{format('%.4f', @cost)} ", style: RatatuiRuby::Style::Style.new(fg: :dark_gray))
      end

      unless @model.empty?
        right << RatatuiRuby::Text::Span.new(content: " #{@model} ", style: RatatuiRuby::Style::Style.new(fg: :cyan))
      end

      line = RatatuiRuby::Text::Line.new(spans: left + right)
      RatatuiRuby::Widgets::Paragraph.new(text: line)
    end

    def build_input_line
      sep_style = RatatuiRuby::Style::Style.new(fg: :dark_gray)
      prompt_style = RatatuiRuby::Style::Style.new(fg: :cyan, modifiers: [:bold])
      input_style = RatatuiRuby::Style::Style.new(fg: :white)

      spans = []
      spans << RatatuiRuby::Text::Span.new(content: "❯ ", style: prompt_style)

      if @loading && @input.empty?
        now = Time.now
        if now - @spinner_last > 0.1
          @spinner_idx = (@spinner_idx + 1) % SPINNER_FRAMES.length
          @spinner_last = now
        end
        spans << RatatuiRuby::Text::Span.new(content: "#{SPINNER_FRAMES[@spinner_idx]} ", style: RatatuiRuby::Style::Style.new(fg: :cyan))
        spans << RatatuiRuby::Text::Span.new(content: @loading_text, style: RatatuiRuby::Style::Style.new(fg: :dark_gray, modifiers: [:italic]))
      else
        spans << RatatuiRuby::Text::Span.new(content: @input, style: input_style)
      end

      line = RatatuiRuby::Text::Line.new(spans: spans)
      RatatuiRuby::Widgets::Paragraph.new(text: line)
    end
  end
end
