# frozen_string_literal: true

require "pastel"

module Crimson
  class TuiStatusBar
    attr_reader :pastel
    attr_accessor :model, :provider, :token_usage, :cost, :status

    def initialize
      @pastel = Pastel.new
      @model = ""
      @provider = ""
      @token_usage = { prompt: 0, completion: 0, total: 0 }
      @cost = 0.0
      @status = "idle"
    end

    def to_s(width = 80)
      left = format_left
      right = format_right
      padding = [width - left.length - right.length, 1].max
      "#{left}#{" " * padding}#{right}"
    end

    def update(model: nil, provider: nil, token_usage: nil, cost: nil, status: nil)
      @model = model if model
      @provider = provider if provider
      @token_usage = token_usage if token_usage
      @cost = cost if cost
      @status = status if status
    end

    private

    def format_left
      model_str = @model.empty? ? "" : @model
      provider_str = @provider.empty? ? "" : "@#{@provider}"
      "#{@pastel.dim("●")} #{@pastel.cyan(model_str)}#{@pastel.dim(provider_str)}"
    end

    def format_right
      token_str = "#{@token_usage[:total]}t"
      cost_str = @cost > 0 ? "($#{'%.2f' % @cost})" : ""
      status_str = case @status
      when "thinking" then @pastel.yellow("thinking...")
      when "streaming" then @pastel.cyan("streaming...")
      when "tool_running" then @pastel.magenta("tool running...")
      else @pastel.dim(@status)
      end
      "#{status_str} #{@pastel.dim(token_str)} #{@pastel.dim(cost_str)}"
    end
  end
end
