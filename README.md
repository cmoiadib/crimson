# Crimson

An open-source Ruby-based minimal coding agent made to get things done.

## Features

- **Multi-provider support** — OpenAI, Anthropic, OpenRouter, Mistral, xAI, and custom OpenAI-compatible endpoints
- **Official SDKs** — Uses the official OpenAI and Anthropic Ruby gems
- **Built-in tools** — Read, write, list files, run commands, and search code
- **Streaming** — Real-time response output as the model generates
- **Skills system** — Customize agent behavior with markdown files
- **Interactive REPL** — Conversational coding assistant in your terminal

## Requirements

- Ruby 3.2+

## Installation

```bash
git clone https://github.com/cmoiadib/crimson.git
cd crimson
bundle install
```

## Setup

```bash
ruby bin/crimson setup
```

This walks you through selecting a provider, entering your API key, and picking a model.

## Usage

Start the interactive REPL:

```bash
ruby bin/crimson
```

### Slash commands

| Command | Description |
|---------|-------------|
| `/help` | Show available commands |
| `/clear` | Clear conversation history |
| `/model` | Show current model |
| `/tools` | List available tools |
| `/exit` | Exit crimson |

### Skills

Add `.md` files to the `skills/` directory to customize agent behavior. These are loaded into the system prompt automatically.

## License

MIT
