# 42 VSCode AutoInstaller

Automated VS Code installer and updater designed for **42 students**.  
This script installs VS Code in your sgoinfre (`~/sgoinfre/vscode`) or home directory (`~/opt/vscode`) if you don't have access to the sgoinfre, adds it to your PATH, and creates a desktop launcher. It works on **Linux** with **Bash** or **Zsh**.

## Features

- Downloads the latest stable VS Code release.
- Installs it in `~/sgoinfre/vscode` or `~/opt/vscode` (no sudo required).
- Updates your shell configuration (`.bashrc` or `.zshrc`) to include VS Code in PATH.
- Creates a `vscode.desktop` launcher on your Desktop.
- Fully automated and colorized terminal output.

## Installation

Run the installer in a single line:

```bash
curl -sSL https://raw.githubusercontent.com/jsesbasti/42-vscode-autoinstaller/refs/heads/master/installer.sh | bash; update-vscode
```
