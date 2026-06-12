# frozen_string_literal: true

require "pastel"
require_relative "tui"

module Crimson
  class OutputHandler
    def initialize
      @pastel = Pastel.new
      @tui = nil
      @first_token = false
    end

    def attach(agent, tui)
      @tui = tui

      agent.on(Agent::Events::AGENT_START) do
        @first_token = false
        @tui.show_loading("Thinking...")
        update_status(agent, status: :thinking)
      end

      agent.on(Agent::Events::MESSAGE_UPDATE) do |_event, delta:, **|
        unless @first_token
          @tui.hide_loading
          @first_token = true
        end
        @tui.insert_content(delta)
        update_status(agent, status: :streaming)
      end

      agent.on(Agent::Events::TOOL_EXECUTION_START) do |_event, tool_name:, args:, **|
        @tui.hide_loading
        path = extract_path(args)
        line = path ? "  #{tool_name}(#{path})" : "  #{tool_name}"
        @tui.insert_content(line)
        update_status(agent, status: :tool_running)
      end

      agent.on(Agent::Events::TOOL_EXECUTION_END) do |_event, result:, is_error:, **|
        truncated = truncate(result.to_s, 200)
        prefix = is_error ? "  -> " : "  -> "
        @tui.insert_content("#{prefix}#{truncated}")
      end

      agent.on(Agent::Events::TOOL_EXECUTION_UPDATE) do |_event, tool_name:, partial_result:, **|
        next unless tool_name == "run_command"
        @tui.insert_content(partial_result.to_s[0..120])
      end

      agent.on(Agent::Events::TURN_START) do
        @tui.show_loading("Thinking...") unless @first_token
      end

      agent.on(Agent::Events::AGENT_END) do
        @tui.hide_loading
        usage = agent.token_usage
        if usage[:total] > 0
          cost = agent.cost_tracker.total_cost
          cost_str = cost > 0 ? " ($#{format("%.4f", cost)})" : ""
          model = agent.config.model rescue ""
          model_str = model.empty? ? "" : " #{model}"
          @tui.insert_content("\n  tokens: #{usage[:prompt]}↑ #{usage[:completion]}↓ = #{usage[:total]}#{cost_str}#{model_str}")
        end
        update_status(agent, status: :idle)
      end
    end

    private

    def update_status(agent, status:)
      token_usage = agent.token_usage rescue { prompt: 0, completion: 0, total: 0 }
      cost = agent.cost_tracker.total_cost rescue 0.0
      model = agent.config.model rescue ""

      @tui.update_status(
        model: model,
        tokens: token_usage,
        cost: cost,
        status: status
      )
    end

    def extract_path(args)
      return nil unless args.is_a?(Hash)
      args["path"] || args[:path]
    rescue
      nil
    end

    def truncate(text, max_len)
      return "" if text.nil?
      cleaned = text.gsub("\n", "\\n")
      cleaned.length > max_len ? "#{cleaned[0...max_len]}..." : cleaned
    end
  end
end
