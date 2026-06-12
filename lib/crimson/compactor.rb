# frozen_string_literal: true

module Crimson
  class Compactor
    DEFAULT_MAX_CONTEXT_TOKENS = 100_000
    KEEP_RECENT_MESSAGES = 4

    def initialize(client:, max_context_tokens: DEFAULT_MAX_CONTEXT_TOKENS, model: nil, provider: nil)
      @client = client
      @max_context_tokens = max_context_tokens
      @token_counter = TokenCounter.new(model: model, provider: provider)
    end

    def needs_compaction?(history)
      estimated_tokens(history) > @max_context_tokens * 0.8
    end

    def compact(history, system_prompt:)
      return history if history.length <= KEEP_RECENT_MESSAGES + 1

      older = history[0...-KEEP_RECENT_MESSAGES]
      recent = history[-KEEP_RECENT_MESSAGES..]

      file_ops = extract_file_operations(history)
      summary = summarize(older, system_prompt, file_ops)

      compacted = []
      compacted << Message::User.new("[Previous conversation summary]\n#{summary}")
      compacted << Message::Assistant.new("Understood. I have the context from the previous conversation.")
      compacted.concat(recent)
      compacted
    end

    private

    def extract_file_operations(history)
      ops = { read: [], modified: [] }
      pending_tool_calls = {}

      history.each do |msg|
        if msg.is_a?(Message::Assistant) && msg.tool_calls
          msg.tool_calls.each do |tc|
            pending_tool_calls[tc.id] = tc
          end
        elsif msg.is_a?(Message::ToolResult)
          tc = pending_tool_calls[msg.tool_call_id]
          if tc
            path = tc.arguments.is_a?(Hash) ? (tc.arguments["path"] || tc.arguments[:path]) : nil
            case tc.name
            when "read_file"
              ops[:read] << path if path
            when "write_file", "edit_file"
              ops[:modified] << path if path
            end
          end
        end
      end

      ops[:read] = ops[:read].compact.uniq
      ops[:modified] = ops[:modified].compact.uniq
      ops
    end

    def summarize(messages, system_prompt, file_ops = { read: [], modified: [] })
      files_section = ""
      if file_ops[:read].any? || file_ops[:modified].any?
        files_section = "\n\nFiles involved in this conversation:\n"
        files_section += "  Read: #{file_ops[:read].join(', ')}\n" if file_ops[:read].any?
        files_section += "  Modified: #{file_ops[:modified].join(', ')}\n" if file_ops[:modified].any?
      end

      summary_prompt = "Summarize the following conversation between a user and an AI coding assistant. " \
        "Preserve all important details: file paths discussed, code changes made, errors encountered, " \
        "decisions reached, and any unresolved issues. Be concise but complete.\n\n" \
        "Conversation:\n#{format_messages(messages)}#{files_section}"

      msgs = [
        Message::System.new("You are a helpful assistant that summarizes conversations concisely."),
        Message::User.new(summary_prompt)
      ]

      response, _usage = @client.chat(messages: msgs, tools: [])
      response&.content || "Summary unavailable"
    end

    def format_messages(messages)
      messages.map do |msg|
        case msg
        when Message::User
          "User: #{msg.content}"
        when Message::Assistant
          tool_str = msg.tool_calls.any? ? " [called: #{msg.tool_calls.map(&:name).join(", ")}]" : ""
          "Assistant: #{msg.content}#{tool_str}"
        when Message::ToolResult
          "Tool (#{msg.name}): #{truncate(msg.content.to_s, 200)}"
        else
          nil
        end
      end.compact.join("\n")
    end

    def estimated_tokens(history)
      @token_counter.count_messages(history)
    end

    def truncate(text, max)
      text.length > max ? "#{text[0...max]}..." : text
    end
  end
end
