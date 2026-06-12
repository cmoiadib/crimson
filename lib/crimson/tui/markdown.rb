# frozen_string_literal: true

require "pastel"

module Crimson
  class TuiMarkdown
    def initialize
      @pastel = Pastel.new
    end

    def render(text)
      return "" if text.nil? || text.empty?

      lines = text.split("\n")
      result = []

      in_code_block = false
      code_lang = ""

      lines.each do |line|
        if line.start_with?("```")
          if in_code_block
            in_code_block = false
            result << @pastel.dim("```")
          else
            in_code_block = true
            code_lang = line[3..].strip
            result << @pastel.dim("```#{code_lang}")
          end
          next
        end

        if in_code_block
          result << @pastel.dim("  #{line}")
        else
          result << render_line(line)
        end
      end

      result.join("\n")
    end

    private

    def render_line(line)
      # Headers
      if line.start_with?("# ")
        return @pastel.bold(line[2..])
      elsif line.start_with?("## ")
        return @pastel.bold(line[3..])
      elsif line.start_with?("### ")
        return @pastel.bold(line[4..])
      end

      # List items
      if line =~ /^\s*[-*]\s/
        return render_list_item(line)
      end

      # Numbered list
      if line =~ /^\s*\d+\.\s/
        return render_numbered_list(line)
      end

      # Inline formatting
      render_inline(line)
    end

    def render_list_item(line)
      indent = line[/^\s*/]
      content = line.sub(/^\s*[-*]\s/, "")
      "#{indent}#{@pastel.cyan("•")} #{render_inline(content)}"
    end

    def render_numbered_list(line)
      indent = line[/^\s*/]
      num = line[/\d+/]
      content = line.sub(/^\s*\d+\.\s/, "")
      "#{indent}#{@pastel.cyan("#{num}.")} #{render_inline(content)}"
    end

    def render_inline(text)
      # Bold **text**
      text = text.gsub(/\*\*(.+?)\*\*/) { @pastel.bold($1) }

      # Italic *text*
      text = text.gsub(/\*(.+?)\*/) { @pastel.italic($1) }

      # Inline code `text`
      text = text.gsub(/`(.+?)`/) { @pastel.dim($1) }

      # Links [text](url)
      text = text.gsub(/\[(.+?)\]\((.+?)\)/) { "#{@pastel.underline($1)} #{@pastel.dim($2)}" }

      text
    end
  end
end
