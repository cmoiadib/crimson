# frozen_string_literal: true

require "reline"
require "pastel"

module Crimson
  class Repl
    def initialize(agent)
      @agent = agent
      @pastel = Pastel.new
      @output_handler = OutputHandler.new
      @output_handler.attach(agent)
      @tui = @output_handler.tui
      setup_readline
    end

    def start
      @output_handler.start

      @tui.add_message(:assistant, "**Crimson v#{VERSION}**")
      @tui.add_message(:assistant, "Type `/help` for commands, `/exit` to quit")

      loop do
        input = Reline.readline("> ", true)

        break if input.nil?
        input = input.strip
        break if input == "/exit" || input == "/quit"
        next if input.empty?

        if input.start_with?("/")
          handle_command(input)
        else
          @tui.add_message(:user, input)
          @agent.prompt(input)
        end
      rescue Interrupt
        @tui.add_message(:assistant, "*Operation cancelled by user.*")
      rescue => e
        @tui.add_message(:error, e.message)
      end

      @output_handler.stop
      @tui.add_message(:assistant, "*Goodbye!*")
      sleep 0.2
    end

    private

    def handle_command(input)
      case input
      when "/help"
        show_help
      when "/clear"
        @agent.reset
        @tui.clear
        @tui.add_message(:assistant, "*Conversation cleared.*")
      when "/model"
        handle_model_switch
      when "/thinking"
        handle_thinking
      when "/tools"
        show_tools
      when "/save"
        @tui.add_message(:assistant, @agent.save_history)
      when "/load"
        @tui.add_message(:assistant, @agent.load_history)
      when "/usage"
        show_usage
      when "/sessions"
        handle_sessions
      when "/name"
        handle_name
      when "/session"
        handle_session_info
      when "/fork"
        handle_fork
      when "/tree"
        handle_tree
      when "/compact"
        handle_compact
      else
        if input.start_with?("/name ")
          handle_name_set(input[6..].strip)
        else
          @tui.add_message(:assistant, "*Unknown command: #{input}. Type `/help` for commands.*")
        end
      end
    end

    def show_help
      help_text = "**Commands:**\n" \
        "- `/help`       Show help message\n" \
        "- `/clear`      Clear conversation history\n" \
        "- `/model`      Switch model\n" \
        "- `/thinking`   Set thinking level\n" \
        "- `/tools`      List available tools\n" \
        "- `/save`       Save conversation\n" \
        "- `/load`       Load conversation\n" \
        "- `/usage`      Show token usage\n" \
        "- `/sessions`   List sessions\n" \
        "- `/name`       Set session name\n" \
        "- `/session`    Show session info\n" \
        "- `/fork`       Fork session\n" \
        "- `/tree`       Show conversation tree\n" \
        "- `/compact`    Compact history\n" \
        "- `/exit`       Exit crimson"
      @tui.add_message(:assistant, help_text)
    end

    def show_tools
      tools = @agent.tool_registry.tool_names.map { |n| "- #{n}" }.join("\n")
      @tui.add_message(:assistant, "**Available tools:**\n#{tools}")
    end

    def show_usage
      usage = @agent.token_usage
      cost = @agent.cost_tracker.total_cost
      text = "**Token usage:**\n" \
        "- Prompt:     #{usage[:prompt]}\n" \
        "- Completion: #{usage[:completion]}\n" \
        "- Total:      #{usage[:total]}"
      text += "\n- Cost:       $#{format('%.4f', cost)}" if cost > 0
      @tui.add_message(:assistant, text)
    end

    def handle_sessions
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session.*")
        return
      end

      manager = SessionManager.new
      sessions = manager.list(cwd: Dir.pwd)
      if sessions.empty?
        @tui.add_message(:assistant, "*No sessions found.*")
      else
        lines = ["**Sessions:**"]
        sessions.each do |s|
          current = s.id == @agent.session_id ? " (current)" : ""
          name_str = s.name ? "[#{s.name}] " : ""
          preview = s.preview || "(no preview)"
          lines << "- `#{s.id[0..7]}` #{name_str}#{preview} #{s.last_timestamp}#{current}"
        end
        @tui.add_message(:assistant, lines.join("\n"))
      end
    end

    def handle_model_switch
      config = @agent.config || Crimson.config
      @tui.add_message(:assistant, "*Current: #{PROVIDERS[config.provider.to_sym][:name]} / #{config.model}*")

      begin
        prompt = TTY::Prompt.new
        models = fetch_available_models(config)
        if models.empty?
          @tui.add_message(:assistant, "*Could not fetch model list.*")
          return
        end

        selected = prompt.select("Select model:", models.map { |m| { name: m, value: m } })
        @agent.switch_model(selected)
        @agent.config.save
        @tui.add_message(:assistant, "*Switched to: #{selected}*")
      rescue => e
        @tui.add_message(:error, "Error switching model: #{e.message}")
      end
    end

    def fetch_available_models(config)
      require "net/http"
      require "uri"
      provider = PROVIDERS[config.provider.to_sym]
      base_url = config.base_url || provider[:base_url]
      url = URI("#{base_url}/models")

      headers = provider[:auth_headers].call(config.api_key)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(url.request_uri, headers)
      response = http.request(request)

      return [] unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      (data["data"] || []).map { |m| m["id"] }.sort
    rescue
      []
    end

    def handle_thinking
      config = @agent.config || Crimson.config
      current = config.thinking_level || "off"
      @tui.add_message(:assistant, "*Current thinking level: #{current}*")

      begin
        prompt = TTY::Prompt.new
        level = prompt.select("Thinking level:", %w[off low medium high].map { |l| { name: l, value: l } })
        config.thinking_level = level
        config.save
        @agent.config = config
        @tui.add_message(:assistant, "*Thinking level set to: #{level}*")
      rescue => e
        @tui.add_message(:error, "Error setting thinking level: #{e.message}")
      end
    end

    def handle_name
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session.*")
        return
      end
      @tui.add_message(:assistant, "*Usage: /name <session name>*")
    end

    def handle_name_set(name)
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session.*")
        return
      end
      if name.empty?
        @tui.add_message(:assistant, "*Usage: /name <session name>*")
        return
      end

      manager = SessionManager.new
      manager.set_name(@agent.session_id, cwd: Dir.pwd, name: name)
      @tui.add_message(:assistant, "*Session name set to: #{name}*")
    end

    def handle_session_info
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session.*")
        return
      end

      manager = SessionManager.new
      header = manager.load_header(@agent.session_id, cwd: Dir.pwd)
      entries = manager.load(@agent.session_id, cwd: Dir.pwd)

      usage = @agent.token_usage
      cost = @agent.cost_tracker.total_cost

      text = "**Session info:**\n" \
        "- ID:       #{@agent.session_id}\n" \
        "- Name:     #{header&.dig('name') || '(unnamed)'}\n" \
        "- Created:  #{header&.dig('timestamp')}\n" \
        "- CWD:      #{@agent.session_cwd}\n" \
        "- Entries:  #{entries.length}\n" \
        "- Tokens:   #{usage[:total]} (#{usage[:prompt]} prompt + #{usage[:completion]} completion)"
      text += "\n- Cost:     $#{format('%.4f', cost)}" if cost > 0

      @tui.add_message(:assistant, text)
    end

    def handle_fork
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session to fork.*")
        return
      end

      manager = SessionManager.new
      last_id = @agent.instance_variable_get(:@last_entry_id)
      new_id = manager.fork(@agent.session_id, cwd: Dir.pwd, from_entry_id: last_id)
      @agent.resume_session(new_id, cwd: Dir.pwd, session_manager: manager)
      @tui.add_message(:assistant, "*Forked to new session: #{new_id[0..7]}*")
    end

    def handle_tree
      unless @agent.session_id
        @tui.add_message(:assistant, "*No active session.*")
        return
      end

      manager = SessionManager.new
      entries = manager.load(@agent.session_id, cwd: Dir.pwd)
      lines = entries.map do |e|
        case e.role
        when "user"
          "- **#{truncate(e.content.to_s, 60)}**"
        when "assistant"
          tool_str = e.tool_calls.any? ? " [#{e.tool_calls.map { |t| t["name"] }.join(", ")}]" : ""
          "  - #{truncate(e.content.to_s, 60)}#{tool_str}"
        when "tool_result"
          "    - #{e.tool_name}: #{truncate(e.content.to_s, 40)}"
        end
      end

      @tui.add_message(:assistant, lines.join("\n"))
    end

    def truncate(text, max_len)
      return "" if text.nil?
      cleaned = text.gsub("\n", "\\n")
      cleaned.length > max_len ? "#{cleaned[0...max_len]}..." : cleaned
    end

    def handle_compact
      if @agent.compactor
        result = @agent.compact!
        @tui.add_message(:assistant, "*#{result}*")
      else
        @tui.add_message(:assistant, "*Compaction not enabled.*")
      end
    end

    def setup_readline
      Reline.completion_proc = method(:file_path_completion)
    end

    def file_path_completion(input)
      prefix = input.strip
      return [] unless prefix.start_with?("@", "./", "~/", "/")

      path_prefix = prefix.start_with?("@") ? prefix[1..] : prefix
      expanded = File.expand_path(path_prefix)

      if File.directory?(expanded)
        Dir.entries(expanded)
          .reject { |e| e.start_with?(".") }
          .map { |e| prefix.end_with?("/") ? "#{prefix}#{e}" : "#{prefix}/#{e}" }
      else
        dir = File.dirname(expanded)
        base = File.basename(expanded)
        return [] unless Dir.exist?(dir)

        Dir.entries(dir)
          .reject { |e| e.start_with?(".") }
          .select { |e| e.downcase.start_with?(base.downcase) }
          .map { |e| prefix.include?("/") ? "#{File.dirname(prefix)}/#{e}" : e }
      end
    rescue => e
      []
    end
  end
end
