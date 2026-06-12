# frozen_string_literal: true

module Crimson
  module Tools
    class FileMutationQueue
      def initialize
        @queues = {}
        @global_mutex = Mutex.new
      end

      def with_file(path)
        normalized = File.expand_path(path)
        queue = @global_mutex.synchronize do
          @queues[normalized] ||= Mutex.new
        end

        queue.synchronize { yield }
      ensure
        @global_mutex.synchronize do
          @queues.delete(normalized) if queue && !queue.locked?
        end
      end
    end
  end
end
