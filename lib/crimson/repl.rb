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
      setup_readline
    end

    def start
      puts @pastel.bold("Crimson v#{VERSION}")
      puts @pastel.dim("Type /help for commands, /exit to quit")
      puts

      loop do
        input = Reline.readline("> ", true)

        break if input.nil?
        input = input.strip
        break if input == "/exit" || input == "/quit"
        next if input.empty?

        if input.start_with?("/")
          handle_command(input)
        else
          @agent.prompt(input)
        end
      rescue => e
        puts @pastel.red("Error: #{e.message}")
      end

      puts @pastel.dim("Goodbye!")
    end

    private

    def handle_command(input)
      case input
      when "/help"
        puts @pastel.bold("Commands:")
        puts "  /help     Show help message"
        puts "  /clear    Clear conversation history"
        puts "  /model    Show current model"
        puts "  /tools    List available tools"
        puts "  /save     Save conversation to file"
        puts "  /load     Load conversation from file"
        puts "  /usage    Show token usage"
        puts "  /sessions List sessions for current directory"
        puts "  /fork     Fork current session into new branch"
        puts "  /tree     Show conversation tree"
        puts "  /compact  Compact conversation history"
        puts "  /exit     Exit crimson"
      when "/clear"
        @agent.reset
        puts @pastel.dim("Conversation cleared.")
      when "/model"
        config = Crimson.config
        puts "Provider: #{PROVIDERS[config.provider.to_sym][:name]}"
        puts "Model: #{config.model}"
      when "/tools"
        puts @pastel.bold("Available tools:")
        @agent.tool_registry.tool_names.each do |name|
          puts "  - #{name}"
        end
      when "/save"
        puts @agent.save_history
      when "/load"
        puts @agent.load_history
      when "/usage"
        usage = @agent.token_usage
        puts @pastel.bold("Token usage:")
        puts "  Prompt:     #{usage[:prompt]}"
        puts "  Completion: #{usage[:completion]}"
        puts "  Total:      #{usage[:total]}"
      when "/sessions"
        handle_sessions
      when "/fork"
        handle_fork
      when "/tree"
        handle_tree
      when "/compact"
        if @agent.compactor
          result = @agent.compact!
          puts @pastel.dim(result)
        else
          puts @pastel.yellow("Compaction not enabled.")
        end
      else
        puts @pastel.yellow("Unknown command: #{input}. Type /help for commands.")
      end
    end

    def handle_sessions
      return puts(@pastel.dim("No active session.")) unless @agent.session_id

      manager = SessionManager.new
      sessions = manager.list(cwd: Dir.pwd)
      if sessions.empty?
        puts @pastel.dim("No sessions found.")
      else
        puts @pastel.bold("Sessions:")
        sessions.each do |s|
          current = s.id == @agent.session_id ? " (current)" : ""
          preview = s.preview || "(no preview)"
          puts "  #{@pastel.cyan(s.id[0..7])} #{preview} #{s.last_timestamp}#{current}"
        end
      end
    end

    def handle_fork
      return puts(@pastel.yellow("No active session to fork.")) unless @agent.session_id

      manager = SessionManager.new
      last_id = @agent.instance_variable_get(:@last_entry_id)
      new_id = manager.fork(@agent.session_id, cwd: Dir.pwd, from_entry_id: last_id)
      @agent.resume_session(new_id, cwd: Dir.pwd, session_manager: manager)
      puts @pastel.dim("Forked to new session: #{new_id[0..7]}")
    end

    def handle_tree
      return puts(@pastel.dim("No active session.")) unless @agent.session_id

      manager = SessionManager.new
      entries = manager.load(@agent.session_id, cwd: Dir.pwd)
      entries.each do |e|
        case e.role
        when "user"
          preview = truncate(e.content.to_s, 60)
          puts "  #{@pastel.cyan("⏺")} #{preview}"
        when "assistant"
          tool_str = e.tool_calls.any? ? " [#{e.tool_calls.map { |t| t["name"] }.join(", ")}]" : ""
          preview = truncate(e.content.to_s, 60)
          puts "  #{@pastel.dim("↳ #{preview}#{tool_str}")}"
        when "tool_result"
          preview = truncate(e.content.to_s, 40)
          puts "  #{@pastel.dim("  → #{e.tool_name}: #{preview}")}"
        end
      end
    end

    def truncate(text, max_len)
      return "" if text.nil?
      cleaned = text.gsub("\n", "\\n")
      cleaned.length > max_len ? "#{cleaned[0...max_len]}..." : cleaned
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
