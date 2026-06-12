# frozen_string_literal: true

require "pastel"
require_relative "tui/status_bar"

module Crimson
  class OutputHandler
    RENDER_INTERVAL = 0.05

    def initialize
      @pastel = Pastel.new
      @status_bar = StatusBar.new
      @buffer = String.new
      @buffer_mutex = Mutex.new
      @render_thread = nil
      @running = false
      @spinner_active = false
      @spinner_thread = nil
      @first_token = false
      @spinner_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
      @spinner_index = 0
    end

    def attach(agent)
      agent.on(Agent::Events::AGENT_START) do
        @first_token = false
        start_spinner
        update_status(agent, status: "thinking")
      end

      agent.on(Agent::Events::MESSAGE_UPDATE) do |_event, delta:, **|
        unless @first_token
          stop_spinner
          @first_token = true
        end
        buffer_write(delta)
        update_status(agent, status: "streaming")
      end

      agent.on(Agent::Events::TOOL_EXECUTION_START) do |_event, tool_name:, args:, **|
        stop_spinner
        path = extract_path(args)
        name_str = path ? "#{tool_name}(#{path})" : tool_name.to_s
        buffer_write("\n  #{@pastel.cyan("⠋")} #{@pastel.cyan(name_str)}")
        update_status(agent, status: "tool_running")
      end

      agent.on(Agent::Events::TOOL_EXECUTION_END) do |_event, tool_name:, result:, is_error:, **|
        truncated = truncate(result.to_s, 120)
        if is_error
          buffer_write("\r  #{@pastel.red("✗")} #{@pastel.red(truncated)}")
        else
          buffer_write("\r  #{@pastel.green("✓")} #{@pastel.dim(truncated)}")
        end
      end

      agent.on(Agent::Events::TOOL_EXECUTION_UPDATE) do |_event, tool_name:, partial_result:, **|
        next unless tool_name == "run_command"
        buffer_write("\r  #{@pastel.dim(partial_result)}")
      end

      agent.on(Agent::Events::TURN_START) do
        start_spinner unless @first_token
      end

      agent.on(Agent::Events::AGENT_END) do
        stop_spinner
        usage = agent.token_usage
        if usage[:total] > 0
          cost = agent.cost_tracker.total_cost
          cost_str = cost > 0 ? " ($#{format("%.4f", cost)})" : ""
          buffer_write(@pastel.dim("\n  tokens: #{usage[:prompt]}↑ #{usage[:completion]}↓ = #{usage[:total]}#{cost_str}\n"))
        end
        update_status(agent, status: "idle")
      end
    end

    def start
      @running = true
      @render_thread = Thread.new { render_loop }
    end

    def stop
      @running = false
      stop_spinner
      @render_thread&.join(2)
      @render_thread = nil
      flush_buffer
    end

    def status_bar
      @status_bar
    end

    private

    def render_loop
      while @running
        sleep RENDER_INTERVAL
        flush_buffer
      end
    end

    def buffer_write(text)
      @buffer_mutex.synchronize { @buffer << text }
    end

    def flush_buffer
      content = nil
      @buffer_mutex.synchronize do
        content = @buffer.dup
        @buffer.clear
      end
      return if content.nil? || content.empty?

      status = @status_bar.render
      $stdout.write("#{content}#{status}")
      $stdout.flush
    end

    def start_spinner
      return if @spinner_active
      @spinner_active = true
      @spinner_thread = Thread.new do
        while @spinner_active
          frame = @spinner_frames[@spinner_index % @spinner_frames.length]
          @spinner_index += 1
          buffer_write("\r  #{@pastel.cyan(frame)} Thinking...")
          sleep 0.08
        end
      end
    end

    def stop_spinner
      return unless @spinner_active
      @spinner_active = false
      @spinner_thread&.join(2)
      @spinner_thread = nil
      buffer_write("\r\e[2K")
    end

    def update_status(agent, status:)
      token_usage = agent.token_usage rescue { prompt: 0, completion: 0, total: 0 }
      cost = agent.cost_tracker.total_cost rescue 0.0
      provider = agent.config.provider rescue ""
      model = agent.config.model rescue ""
      @status_bar.update(model: model, provider: provider, token_usage: token_usage, cost: cost, status: status)
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
