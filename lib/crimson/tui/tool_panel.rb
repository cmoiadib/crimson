# frozen_string_literal: true

require "pastel"

module Crimson
  class TuiToolPanel
    attr_reader :pastel, :name, :args, :result, :active, :error, :timestamp

    def initialize(name, args = {})
      @pastel = Pastel.new
      @name = name
      @args = args
      @result = nil
      @active = true
      @error = false
      @timestamp = Time.now
      @spinner_index = 0
      @spinner_frames = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]
    end

    def complete(result = nil, error: false)
      @active = false
      @result = result
      @error = error
    end

    def to_s(width = 80)
      status = @active ? spinner_frame : (@error ? @pastel.red("✗") : @pastel.green("✓"))
      name_str = @pastel.cyan(@name)
      args_str = format_args(width - 40)
      "#{status} #{name_str}(#{args_str})"
    end

    def result_preview(max_len = 100)
      return nil if @result.nil?
      str = @result.to_s
      str.length > max_len ? "#{str[0...max_len]}..." : str
    end

    private

    def format_args(max_len)
      return "" if @args.nil? || @args.empty?
      str = @args.to_s
      str.length > max_len ? "#{str[0...max_len]}..." : str
    end

    def spinner_frame
      frame = @spinner_frames[@spinner_index % @spinner_frames.length]
      @spinner_index += 1
      @pastel.cyan(frame)
    end
  end
end
