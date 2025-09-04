# Quick Functions 🚀

> **Language | 语言**: [🇺🇸 English](README.md) | [🇨🇳 中文](README_CN.md)

A convenient terminal utility function library to help developers quickly set up commonly used shell functions.

## Features

### `devup` - Node.js Local Package Force Update Tool
An automation tool for force-updating local Node.js packages and starting development servers. Especially useful for local package development in monorepo projects.

- 🔄 Automatically execute `pnpm pack` to build the latest package
- 📦 Intelligently find the latest `.tgz` files (sorted by modification time)
- 🗑️ Force remove and reinstall packages (solving the issue of same version not updating)
- 🚀 Automatically start development server
- 🌍 Bilingual prompts (Chinese/English)
- 💻 Support for zsh and bash
- 🖥️ Cross-platform compatible (macOS/Linux)
- 🛡️ Safe path handling (supports spaces and special characters)

## Quick Installation

```bash
# Clone the project
git clone https://github.com/choufeng/quick-functions ~/quick-functions
cd ~/quick-functions

# Install
./install.sh

# Start using
devup
```

## Manual Installation

```bash
# 1. Copy function files to home directory
cp functions/devup-functions.sh ~/.quick-functions/functions/

# 2. Add to shell configuration file
# For zsh:
echo 'source $HOME/.quick-functions/load.sh' >> ~/.zshrc

# For bash:
echo 'source $HOME/.quick-functions/load.sh' >> ~/.bashrc

# 3. Reload configuration
source ~/.zshrc  # or source ~/.bashrc
```

## Configuration

### Default Configuration for devup Function
Default configuration works for `uc-frontend` project without modification:

```bash
# Default paths (works for most cases)
package_dir="$HOME/development/uc-frontend/packages/modal--agent-orders.react"
app_dir="$HOME/development/uc-frontend/apps/lab"
package_name="@uc/modal--agent-orders.react"
```

### Custom Configuration
To modify, edit `~/.quick-functions/functions/devup-functions.sh`:

```bash
# Custom configuration example
local package_dir="$HOME/your-project/packages/your-package"
local app_dir="$HOME/your-project/apps/your-app"
local package_name="@your-org/your-package-name"
```

## Usage

### devup Command
```bash
devup  # Execute complete package update and startup process
```

This command will:
1. Switch to package directory and execute `pnpm pack`
2. Switch back to application directory
3. Remove existing package
4. Install latest packed local package
5. Start development server

### Configuration Helper
```bash
devup_config  # Show current configuration
```

## Management

### Update Functions
```bash
~/.quick-functions/update.sh  # Update from git repository
```

## Installation Location

The installer creates a safe installation directory:

```
~/.quick-functions/
├── functions/
│   └── devup-functions.sh
├── load.sh              # Auto-loader for all functions
└── update.sh            # Update script
```

## Supported Environments

- ✅ macOS (zsh/bash)
- ✅ Linux (zsh/bash)
- ✅ Windows WSL (zsh/bash)
- ✅ Paths with spaces and special characters

## Path Safety

This project handles path safety issues:
- ✅ Supports clone paths with spaces (e.g., `/Users/John Doe/My Projects/`)
- ✅ Supports special characters in paths
- ✅ Uses fixed installation directory `~/.quick-functions`
- ✅ All paths are properly quoted and escaped

## Contributing

Welcome to submit Issues and Pull Requests!

### Development Workflow
```bash
# 1. Fork and clone
git clone <your-fork>

# 2. Make changes to functions/
# 3. Test with ./test.sh
# 4. Submit PR
```

## License

MIT License

---

**Quick Functions** - Making terminal development faster and easier! 🚀
