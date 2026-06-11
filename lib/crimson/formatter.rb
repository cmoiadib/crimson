require 'pastel'

module Crimson
  module Formatter
    @pastel = Pastel.new

    def self.format(text)
      return "" if text.nil? || text.empty?

      result = text.dup

      # Code blocks (```...```) — preserve content, color cyan
      result = result.gsub(/```(\w*)\n(.*?)```/m) do
        lang = $1.empty? ? "" : " [#{$1}]"
        code = $2
        @pastel.cyan("```#{lang}\n#{code}```")
      end

      # Inline code (`...`)
      result = result.gsub(/`([^`]+)`/) do
        @pastel.cyan.on_dark($1)
      end

      # Bold (**...**)
      result = result.gsub(/\*\*([^*]+)\*\*/) do
        @pastel.bold($1)
      end

      # Italic (*...*)
      result = result.gsub(/(?<!\*)\*([^*]+)\*(?!\*)/) do
        @pastel.italic($1)
      end

      # Headers (# ## ###)
      result = result.gsub(/^### (.+)$/) do
        @pastel.bold.yellow($1)
      end
      result = result.gsub(/^## (.+)$/) do
        @pastel.bold.yellow($1)
      end
      result = result.gsub(/^# (.+)$/) do
        @pastel.bold.yellow($1)
      end

      result
    end
  end
end
