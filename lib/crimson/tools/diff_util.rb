# frozen_string_literal: true

require "diff/lcs"
require "pastel"

module Crimson
  module Tools
    module DiffUtil
      def self.format_diff(old_text, new_text, path)
        pastel = Pastel.new
        old_lines = old_text.lines.map(&:chomp)
        new_lines = new_text.lines.map(&:chomp)

        changes = Diff::LCS.sdiff(old_lines, new_lines)

        output = []
        output << pastel.dim("--- #{path}")
        output << pastel.dim("+++ #{path}")

        changes.each do |change|
          case change.action
          when "-"
            output << pastel.red("- #{change.old_element}")
          when "+"
            output << pastel.green("+ #{change.new_element}")
          when "!"
            output << pastel.red("- #{change.old_element}")
            output << pastel.green("+ #{change.new_element}")
          when "="
            output << pastel.dim("  #{change.old_element}")
          end
        end

        output.join("\n")
      end
    end
  end
end
