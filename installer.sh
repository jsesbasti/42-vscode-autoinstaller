#!/usr/bin/env bash
set -e

# Color definitions
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

# Header
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════╗"
echo -e "║${BOLD}     Visual Studio Code Installer Script       ${RESET}${CYAN}║"
echo -e "║${BOLD}        Created by tomaquet18 (alefern2)       ${RESET}${CYAN}║"
echo -e "║${BOLD}          Edited by jsebasti (jsebasti)        ${RESET}${CYAN}║"
echo -e "╚═══════════════════════════════════════════════╝"
echo -e "${RESET}"

UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/jsesbasti/42-vscode-autoinstaller/master/update-vscode"
BIN_DIR="$HOME/bin"
UPDATE_SCRIPT_PATH="$BIN_DIR/update-vscode"

# Make sure $HOME/bin exists
if [ ! -d "$BIN_DIR" ]; then
    echo -e "${BLUE}Creating $BIN_DIR ...${RESET}"
    mkdir -p "$BIN_DIR"
else
    echo -e "${YELLOW}$BIN_DIR already exists, skipping creation.${RESET}"
fi

# Fetch update-vscode only if it isn't already there
if [ ! -f "$UPDATE_SCRIPT_PATH" ]; then
    echo -e "${MAGENTA}Downloading update-vscode to $UPDATE_SCRIPT_PATH ...${RESET}"
    curl -sSL "$UPDATE_SCRIPT_URL" -o "$UPDATE_SCRIPT_PATH"
else
    echo -e "${YELLOW}update-vscode already present in $BIN_DIR, skipping download.${RESET}"
fi

echo -e "${BLUE}Making update-vscode executable...${RESET}"
chmod +x "$UPDATE_SCRIPT_PATH"

# Detect shell and choose rc file
case "$SHELL" in
    */zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    */bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    *)
        echo -e "${YELLOW}Unknown shell ($SHELL), defaulting to .bashrc${RESET}"
        RC_FILE="$HOME/.bashrc"
        ;;
esac
echo -e "${BLUE}Using rc file:${RESET} $RC_FILE"

# Add $HOME/bin to PATH only if it isn't already there
if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}$BIN_DIR already in PATH, skipping.${RESET}"
else
    echo -e "${BLUE}Adding $BIN_DIR to PATH in $RC_FILE${RESET}"
    {
        echo ""
        echo "# Add $BIN_DIR to PATH"
        echo "export PATH=\"$BIN_DIR:\$PATH\""
    } >> "$RC_FILE"
fi

echo -e "${GREEN}\n✔ update-vscode installed in $BIN_DIR${RESET}"
echo -e "\nReload your shell to apply PATH changes:"
echo -e "    ${BOLD}source $RC_FILE${RESET}\n"
exec "$SHELL" -l
