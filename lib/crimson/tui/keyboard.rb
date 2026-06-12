# frozen_string_literal: true

require "io/console"

module Crimson
  class TuiKeyboard
    CTRL_C = "\x03"
    CTRL_E = "\x05"
    CTRL_S = "\x13"
    CTRL_T = "\x14"
    CTRL_L = "\x0C"
    ESC = "\e"
    ARROW_UP = "\e[A"
    ARROW_DOWN = "\e[B"
    ARROW_RIGHT = "\e[C"
    ARROW_LEFT = "\e[D"

    def initialize
      @handlers = {}
      @running = false
      @thread = nil
    end

    def on(key, &block)
      @handlers[key] = []
      @handlers[key] << block
    end

    def start
      return if @running

      @running = true
      @thread = Thread.new { input_loop }
    end

    def stop
      @running = false
      @thread&.join(1)
      @thread = nil
    end

    private

    def input_loop
      while @running
        begin
          c = $stdin.getch
          handle_input(c)
        rescue => e
          # Ignore input errors
        end
      end
    end

    def handle_input(char)
      case char
      when CTRL_C
        trigger(:ctrl_c)
      when CTRL_E
        trigger(:ctrl_e)
      when CTRL_S
        trigger(:ctrl_s)
      when CTRL_T
        trigger(:ctrl_t)
      when CTRL_L
        trigger(:ctrl_l)
      when ESC
        # Read escape sequence
        seq = $stdin.getch
        if seq == "["
          direction = $stdin.getch
          case direction
          when "A" then trigger(:arrow_up)
          when "B" then trigger(:arrow_down)
          when "C" then trigger(:arrow_right)
          when "D" then trigger(:arrow_left)
          end
        end
      end
    end

    def trigger(key)
      return unless @handlers[key]
      @handlers[key].each { |handler| handler.call }
    end
  end
end
