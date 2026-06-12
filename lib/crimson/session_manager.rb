# frozen_string_literal: true

require "securerandom"
require "json"
require "fileutils"
require "digest"

module Crimson
  SessionMeta = Struct.new(:id, :entry_count, :last_timestamp, :preview, :name, :mtime, keyword_init: true)

  class SessionManager
    CURRENT_SESSION_VERSION = 1

    def initialize(sessions_dir: nil)
      @sessions_dir = sessions_dir || File.join(Crimson::CONFIG_DIR, "sessions")
    end

    def create(cwd:, parent_session: nil)
      id = SecureRandom.uuid
      FileUtils.mkdir_p(session_dir(cwd: cwd))
      header = {
        type: "session_header",
        version: CURRENT_SESSION_VERSION,
        id: id,
        timestamp: Time.now.utc.iso8601,
        cwd: cwd,
        parentSession: parent_session
      }
      File.write(session_file(id, cwd: cwd), JSON.generate(header) + "\n")
      id
    end

    def load(session_id, cwd:)
      file = session_file(session_id, cwd: cwd)
      return [] unless File.exist?(file)

      entries = []
      File.foreach(file) do |line|
        line = line.strip
        next if line.empty?
        begin
          parsed = JSON.parse(line)
          next if parsed["type"] == "session_header"
          entries << SessionEntry.from_h(parsed)
        rescue JSON::ParserError
          next
        end
      end
      entries
    end

    def load_header(session_id, cwd:)
      file = session_file(session_id, cwd: cwd)
      return nil unless File.exist?(file)

      File.foreach(file) do |line|
        line = line.strip
        next if line.empty?
        begin
          parsed = JSON.parse(line)
          return parsed if parsed["type"] == "session_header"
        rescue JSON::ParserError
          next
        end
      end
      nil
    end

    def append(session_id, cwd:, entry:)
      file = session_file(session_id, cwd: cwd)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "a") { |f| f.puts(entry.to_json) }
    end

    def list(cwd:)
      dir = session_dir(cwd: cwd)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "*.jsonl")).filter_map do |file|
        id = File.basename(file, ".jsonl")
        entries = []
        last_user_content = nil
        session_name = nil

        File.foreach(file) do |line|
          line = line.strip
          next if line.empty?
          begin
            parsed = JSON.parse(line)
            if parsed["type"] == "session_header"
              session_name = parsed["name"]
              next
            end
            entry = SessionEntry.from_h(parsed)
            entries << entry
            last_user_content = entry.content if entry.role == "user"
          rescue JSON::ParserError
            next
          end
        end

        next if entries.empty?

        SessionMeta.new(
          id: id,
          entry_count: entries.length,
          last_timestamp: entries.last.timestamp,
          preview: last_user_content && last_user_content.length > 80 ? last_user_content[0, 77] + "..." : last_user_content,
          name: session_name,
          mtime: File.mtime(file)
        )
      end.sort_by { |s| s.mtime }.reverse
    end

    def set_name(session_id, cwd:, name:)
      file = session_file(session_id, cwd: cwd)
      return unless File.exist?(file)

      lines = File.readlines(file)
      lines.each_with_index do |line, idx|
        stripped = line.strip
        next if stripped.empty?
        begin
          parsed = JSON.parse(stripped)
          if parsed["type"] == "session_header"
            parsed["name"] = name
            lines[idx] = JSON.generate(parsed) + "\n"
            File.write(file, lines.join)
            return
          end
        rescue JSON::ParserError
          next
        end
      end
    end

    def latest(cwd:)
      sessions = list(cwd: cwd)
      sessions.first
    end

    def fork(session_id, cwd:, from_entry_id:)
      entries = load(session_id, cwd: cwd)
      fork_point = entries.index { |e| e.id == from_entry_id }
      raise "Entry #{from_entry_id} not found in session #{session_id}" unless fork_point

      prefix = entries[0..fork_point]
      new_id = SecureRandom.uuid
      prefix.each { |e| append(new_id, cwd: cwd, entry: e) }
      new_id
    end

    def delete(session_id, cwd:)
      file = session_file(session_id, cwd: cwd)
      File.delete(file) if File.exist?(file)
    end

    def session_file(session_id, cwd:)
      File.join(session_dir(cwd: cwd), "#{session_id}.jsonl")
    end

    def dir_hash(cwd:)
      Digest::SHA256.hexdigest(cwd)[0, 12]
    end

    private

    def session_dir(cwd:)
      File.join(@sessions_dir, dir_hash(cwd: cwd))
    end
  end
end
