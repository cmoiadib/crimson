require 'json'

module Crimson
  module Tools
    module ReadFile
      def self.definition
        {
          type: "function",
          function: {
            name: "read_file",
            description: "Read the contents of a file at the given path. Returns the file content as a string.",
            parameters: {
              type: "object",
              properties: {
                path: {
                  type: "string",
                  description: "The path to the file to read"
                }
              },
              required: ["path"]
            }
          }
        }
      end

      def self.anthropic_definition
        {
          name: "read_file",
          description: "Read the contents of a file at the given path. Returns the file content as a string.",
          input_schema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The path to the file to read"
              }
            },
            required: ["path"]
          }
        }
      end

      def self.call(path:)
        return "Error: No path provided" if path.nil? || path.strip.empty?

        expanded = File.expand_path(path)

        unless File.exist?(expanded)
          return "Error: File not found: #{path}"
        end

        unless File.file?(expanded)
          return "Error: Not a file: #{path}"
        end

        begin
          File.read(expanded)
        rescue => e
          "Error reading file: #{e.message}"
        end
      end
    end

    module WriteFile
      def self.definition
        {
          type: "function",
          function: {
            name: "write_file",
            description: "Write content to a file. Creates the file if it does not exist, overwrites if it does.",
            parameters: {
              type: "object",
              properties: {
                path: {
                  type: "string",
                  description: "The path to the file to write"
                },
                content: {
                  type: "string",
                  description: "The content to write to the file"
                }
              },
              required: ["path", "content"]
            }
          }
        }
      end

      def self.anthropic_definition
        {
          name: "write_file",
          description: "Write content to a file. Creates the file if it does not exist, overwrites if it does.",
          input_schema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The path to the file to write"
              },
              content: {
                type: "string",
                description: "The content to write to the file"
              }
            },
            required: ["path", "content"]
          }
        }
      end

      def self.call(path:, content:)
        return "Error: No path provided" if path.nil? || path.strip.empty?

        expanded = File.expand_path(path)
        dir = File.dirname(expanded)

        begin
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
          File.write(expanded, content)
          "Successfully wrote to #{path}"
        rescue => e
          "Error writing file: #{e.message}"
        end
      end
    end

    module ListDirectory
      def self.definition
        {
          type: "function",
          function: {
            name: "list_directory",
            description: "List files and directories at the given path. Returns directory contents.",
            parameters: {
              type: "object",
              properties: {
                path: {
                  type: "string",
                  description: "The directory path to list. Defaults to current directory."
                }
              },
              required: ["path"]
            }
          }
        }
      end

      def self.anthropic_definition
        {
          name: "list_directory",
          description: "List files and directories at the given path. Returns directory contents.",
          input_schema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The directory path to list. Defaults to current directory."
              }
            },
            required: ["path"]
          }
        }
      end

      def self.call(path: ".")
        expanded = File.expand_path(path)

        unless Dir.exist?(expanded)
          return "Error: Directory not found: #{path}"
        end

        entries = Dir.entries(expanded).sort
        entries.delete(".")
        entries.delete("..")

        result = entries.map do |entry|
          full_path = File.join(expanded, entry)
          if File.directory?(full_path)
            "#{entry}/"
          else
            entry
          end
        end

        result.join("\n")
      rescue => e
        "Error listing directory: #{e.message}"
      end
    end

    module RunCommand
      def self.definition
        {
          type: "function",
          function: {
            name: "run_command",
            description: "Execute a shell command and return its stdout and stderr output.",
            parameters: {
              type: "object",
              properties: {
                command: {
                  type: "string",
                  description: "The shell command to execute"
                },
                timeout: {
                  type: "integer",
                  description: "Timeout in seconds (default: 30)"
                }
              },
              required: ["command"]
            }
          }
        }
      end

      def self.anthropic_definition
        {
          name: "run_command",
          description: "Execute a shell command and return its stdout and stderr output.",
          input_schema: {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The shell command to execute"
              },
              timeout: {
                type: "integer",
                description: "Timeout in seconds (default: 30)"
              }
            },
            required: ["command"]
          }
        }
      end

      def self.call(command:, timeout: 30)
        return "Error: No command provided" if command.nil? || command.strip.empty?

        begin
          stdout, stderr, status = Open3.capture3(command, timeout: timeout)
          output = ""
          output << stdout if stdout && !stdout.empty?
          output << stderr if stderr && !stderr.empty?
          output = "(no output)" if output.strip.empty?
          output << "\n(exit code: #{status.exitstatus})" unless status.success?
          output
        rescue Timeout::Error
          "Error: Command timed out after #{timeout} seconds"
        rescue => e
          "Error executing command: #{e.message}"
        end
      end
    end

    module SearchFiles
      def self.definition
        {
          type: "function",
          function: {
            name: "search_files",
            description: "Search for a pattern in files using grep. Returns matching file paths and line numbers.",
            parameters: {
              type: "object",
              properties: {
                pattern: {
                  type: "string",
                  description: "The regex pattern to search for"
                },
                path: {
                  type: "string",
                  description: "The directory to search in. Defaults to current directory."
                },
                file_pattern: {
                  type: "string",
                  description: "Glob pattern to filter files (e.g. '*.rb'). Defaults to all files."
                }
              },
              required: ["pattern"]
            }
          }
        }
      end

      def self.anthropic_definition
        {
          name: "search_files",
          description: "Search for a pattern in files using grep. Returns matching file paths and line numbers.",
          input_schema: {
            type: "object",
            properties: {
              pattern: {
                type: "string",
                description: "The regex pattern to search for"
              },
              path: {
                type: "string",
                description: "The directory to search in. Defaults to current directory."
              },
              file_pattern: {
                type: "string",
                description: "Glob pattern to filter files (e.g. '*.rb'). Defaults to all files."
              }
            },
            required: ["pattern"]
          }
        }
      end

      def self.call(pattern:, path: ".", file_pattern: nil)
        return "Error: No pattern provided" if pattern.nil? || pattern.strip.empty?

        expanded = File.expand_path(path)
        cmd = ["grep", "-rn", "--color=never", "-E"]
        cmd += ["--include=#{file_pattern}"] if file_pattern
        cmd << pattern
        cmd << expanded

        begin
          stdout, stderr, status = Open3.capture3(*cmd, timeout: 30)

          if status.exitstatus == 1
            return "No matches found."
          end

          lines = stdout.lines
          if lines.length > 100
            "#{lines.first(100).join}\n... (truncated, #{lines.length - 100} more matches)"
          else
            stdout
          end
        rescue => e
          "Error searching files: #{e.message}"
        end
      end
    end

    def self.all
      [ReadFile, WriteFile, ListDirectory, RunCommand, SearchFiles]
    end
  end
end
