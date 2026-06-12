# frozen_string_literal: true

require "securerandom"
require "json"

module Crimson
  class SessionEntry
    attr_accessor :id, :parent_id, :role, :content,
                  :tool_calls, :tool_call_id, :tool_name,
                  :token_usage, :timestamp,
                  :read_files, :modified_files

    def initialize(attrs = {})
      @id = attrs[:id] || SecureRandom.uuid
      @parent_id = attrs[:parent_id]
      @role = attrs[:role]
      @content = attrs[:content]
      @tool_calls = attrs[:tool_calls] || []
      @tool_call_id = attrs[:tool_call_id]
      @tool_name = attrs[:tool_name]
      @token_usage = attrs[:token_usage] || {}
      @timestamp = attrs[:timestamp] || Time.now.utc.iso8601
      @read_files = attrs[:read_files] || []
      @modified_files = attrs[:modified_files] || []
    end

    def to_h
      h = {
        id: @id,
        parentId: @parent_id,
        role: @role,
        content: @content,
        toolCalls: @tool_calls,
        timestamp: @timestamp
      }
      h[:toolCallId] = @tool_call_id if @tool_call_id
      h[:toolName] = @tool_name if @tool_name
      h[:tokenUsage] = @token_usage unless @token_usage.empty?
      h[:readFiles] = @read_files unless @read_files.empty?
      h[:modifiedFiles] = @modified_files unless @modified_files.empty?
      h
    end

    def to_json(*_args)
      JSON.generate(to_h)
    end

    def self.from_h(hash)
      new(
        id: hash[:id] || hash["id"],
        parent_id: hash[:parentId] || hash["parentId"],
        role: hash[:role] || hash["role"],
        content: hash[:content] || hash["content"],
        tool_calls: hash[:toolCalls] || hash["toolCalls"] || [],
        tool_call_id: hash[:toolCallId] || hash["toolCallId"],
        tool_name: hash[:toolName] || hash["toolName"],
        token_usage: hash[:tokenUsage] || hash["tokenUsage"] || {},
        timestamp: hash[:timestamp] || hash["timestamp"],
        read_files: hash[:readFiles] || hash["readFiles"] || [],
        modified_files: hash[:modifiedFiles] || hash["modifiedFiles"] || []
      )
    end

    def self.from_message(message, parent_id:, read_files: [], modified_files: [])
      case message
      when Message::User
        new(role: "user", content: message.content, parent_id: parent_id)
      when Message::Assistant
        tc_data = message.tool_calls.map do |tc|
          { "id" => tc.id, "name" => tc.name, "arguments" => tc.arguments }
        end
        new(
          role: "assistant",
          content: message.content,
          parent_id: parent_id,
          tool_calls: tc_data
        )
      when Message::ToolResult
        new(
          role: "tool_result",
          content: message.content,
          parent_id: parent_id,
          tool_call_id: message.tool_call_id,
          tool_name: message.name,
          read_files: read_files,
          modified_files: modified_files
        )
      else
        new(role: "system", content: message&.content.to_s, parent_id: parent_id)
      end
    end

    def to_message
      case @role
      when "user"
        Message::User.new(@content)
      when "assistant"
        tcs = (@tool_calls || []).map do |tc|
          Message::ToolCall.new(
            id: tc["id"],
            name: tc["name"],
            arguments: tc["arguments"]
          )
        end
        Message::Assistant.new(content: @content, tool_calls: tcs)
      when "tool_result"
        Message::ToolResult.new(
          tool_call_id: @tool_call_id,
          name: @tool_name,
          content: @content
        )
      else
        nil
      end
    end
  end
end
