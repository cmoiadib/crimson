# frozen_string_literal: true

require "pastel"
require "io/console"

module Crimson
  class StatusBar
    attr_accessor :model, :provider, :token_usage, :cost, :status

    def initialize
      @pastel = Pastel.new
      @model = ""
      @provider = ""
      @token_usage = { prompt: 0, completion: 0, total: 0 }
      @cost = 0.0
      @status = "idle"
      @last_rendered = ""
    end

    def update(model: nil, provider: nil, token_usage: nil, cost: nil, status: nil)
      @model = model if model
      @provider = provider if provider
      @token_usage = token_usage if token_usage
      @cost = cost if cost
      @status = status if status
    end

    def render
      width = terminal_width
      left = format_left
      right = format_right
      padding = [width - visible_length(left) - visible_length(right) - 1, 1].max
      line = "#{left}#{" " * padding}#{right}"

      return "" if line == @last_rendered
      @last_rendered = line

      rows = terminal_height
      # Save cursor, move to bottom row, clear line, write status, restore cursor
      "\e[s\e[#{rows};1H\e[2K#{line}\e[u"
    end

    private

    def format_left
      parts = []
      parts << @pastel.dim("●")
      parts << @pastel.cyan(@model) unless @model.empty?
      parts << @pastel.dim(@provider) unless @provider.empty?
      parts.compact.join(" ")
    end

    def format_right
      parts = []
      case @status
      when "thinking"
        parts << @pastel.yellow("thinking...")
      when "streaming"
        parts << @pastel.cyan("streaming...")
      when "tool_running"
        parts << @pastel.magenta("tool running...")
      else
        parts << @pastel.dim("idle")
      end

      if @token_usage[:total] > 0
        parts << @pastel.dim("#{@token_usage[:total]}t")
      end

      if @cost > 0
        parts << @pastel.dim("$#{format('%.2f', @cost)}")
      end

      parts.join(" ")
    end

    def terminal_width
      IO.console&.winsize&.[](1) || 80
    rescue
      80
    end

    def terminal_height
      IO.console&.winsize&.[](0) || 24
    rescue
      24
    end

    def visible_length(str)
      str.gsub(/\e\[[0-9;]*m/, "").length
    end
  end
end
