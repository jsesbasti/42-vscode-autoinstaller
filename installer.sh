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
echo -e "║${BOLD}   VS Code / VSCodium Installer Script         ${RESET}${CYAN}║"
echo -e "║${BOLD}      Created by tomaquet18 (alefern2)         ${RESET}${CYAN}║"
echo -e "╚═══════════════════════════════════════════════╝"
echo -e "${RESET}"

# --- Editor selection: --vscode / --vscodium / -e|--editor <name> ---
EDITOR_CHOICE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --vscode)
            EDITOR_CHOICE="vscode"
            shift
            ;;
        --vscodium)
            EDITOR_CHOICE="vscodium"
            shift
            ;;
        -e|--editor)
            EDITOR_CHOICE="${2,,}"
            shift 2
            ;;
        *)
            echo -e "${YELLOW}Unknown option: $1 (ignored)${RESET}"
            shift
            ;;
    esac
done

if [ -z "$EDITOR_CHOICE" ]; then
    if [ -t 0 ]; then
        echo -e "${BLUE}Which editor do you want to install/update?${RESET}"
        PS3="Choose an option: "
        select opt in "VS Code" "VSCodium"; do
            case "$opt" in
                "VS Code")
                    EDITOR_CHOICE="vscode"
                    break
                    ;;
                "VSCodium")
                    EDITOR_CHOICE="vscodium"
                    break
                    ;;
                *)
                    echo -e "${YELLOW}Invalid option, try again.${RESET}"
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}No editor specified and not running interactively, defaulting to VS Code.${RESET}"
        echo -e "${YELLOW}(use --vscode or --vscodium to choose explicitly)${RESET}"
        EDITOR_CHOICE="vscode"
    fi
fi

case "$EDITOR_CHOICE" in
    vscode)
        EDITOR_LABEL="Visual Studio Code"
        EDITOR_SUBDIR="vscode"
        BIN_NAME="code"
        STARTUP_WM_CLASS="Code"
        DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-x64"
        VERSION_API="https://update.code.visualstudio.com/api/latest/linux-x64/stable"
        ;;
    vscodium)
        EDITOR_LABEL="VSCodium"
        EDITOR_SUBDIR="vscodium"
        BIN_NAME="codium"
        STARTUP_WM_CLASS="VSCodium"
        VERSION_API="https://api.github.com/repos/VSCodium/vscodium/releases/latest"
        ;;
    *)
        echo -e "${RED}Unknown editor: $EDITOR_CHOICE (expected 'vscode' or 'vscodium')${RESET}"
        exit 1
        ;;
esac

echo -e "${GREEN}Selected editor: $EDITOR_LABEL${RESET}"

# Generate random temp filename
TMPFILE="/tmp/${EDITOR_SUBDIR}_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12).tar.gz"

# Target directory
# Prefer sgoinfre (42 campus storage) if it exists and is writable,
# otherwise fall back to ~/opt/<editor> for non-42 / no-sgoinfre setups.
if [ -d "$HOME/sgoinfre" ] && [ -w "$HOME/sgoinfre" ]; then
    TARGET_DIR="$HOME/sgoinfre/$EDITOR_SUBDIR"
    echo -e "${BLUE}sgoinfre detected, installing there.${RESET}"
else
    TARGET_DIR="$HOME/opt/$EDITOR_SUBDIR"
    echo -e "${YELLOW}sgoinfre not found or not writable, falling back to $TARGET_DIR${RESET}"
fi
EDITOR_BIN_PATH="$TARGET_DIR/bin"

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

# --- Version check: skip the whole update dance if already on latest stable ---
if [ "$EDITOR_CHOICE" = "vscode" ]; then
    # VS Code's public update API returns the current stable version directly.
    LATEST_VERSION=$(curl -sSL "$VERSION_API" 2>/dev/null | grep -oP '"productVersion"\s*:\s*"\K[^"]+' || true)
else
    # VSCodium ships via GitHub releases; the tag_name is the version, and we
    # also need to grab the matching linux-x64 .tar.gz asset's direct URL.
    RELEASE_JSON=$(curl -sSL "$VERSION_API" 2>/dev/null || true)
    LATEST_VERSION=$(echo "$RELEASE_JSON" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -n1 || true)
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' \
        | grep -i 'linux-x64' \
        | grep '\.tar\.gz$' \
        | head -n1 || true)
fi

CURRENT_VERSION=""
if [ -x "$EDITOR_BIN_PATH/$BIN_NAME" ]; then
    CURRENT_VERSION=$("$EDITOR_BIN_PATH/$BIN_NAME" --version 2>/dev/null | head -n1 || true)
fi

if [ -n "$LATEST_VERSION" ] && [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo -e "${GREEN}Already up to date (version $CURRENT_VERSION). Nothing to do.${RESET}"
    exit 0
fi

if [ -n "$LATEST_VERSION" ]; then
    if [ -n "$CURRENT_VERSION" ]; then
        echo -e "${YELLOW}Installed version: $CURRENT_VERSION — latest stable: $LATEST_VERSION. Updating...${RESET}"
    else
        echo -e "${YELLOW}No existing installation detected. Installing latest stable ($LATEST_VERSION)...${RESET}"
    fi
else
    echo -e "${YELLOW}Could not reach the update API, proceeding with install/update anyway.${RESET}"
fi

if [ "$EDITOR_CHOICE" = "vscodium" ] && [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Could not determine a VSCodium download URL from the GitHub API.${RESET}"
    echo -e "${YELLOW}This can happen if GitHub's API rate-limits unauthenticated requests. Try again later.${RESET}"
    exit 1
fi

# --- Handle existing installation (update case) ---
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Existing installation found at $TARGET_DIR${RESET}"

    # Best-effort: kill anything *on this machine* with open file handles
    # inside TARGET_DIR. This helps in the common local case, but on 42's
    # NFS-shared $HOME it often finds nothing, because the process holding
    # the file can be running on a *different* cluster machine entirely
    # (e.g. the editor left open on another PC on campus) — invisible to
    # fuser/lsof here and impossible to kill from this host.
    if command -v fuser >/dev/null 2>&1; then
        echo -e "${YELLOW}Checking for local processes with open files in $TARGET_DIR...${RESET}"
        fuser -k "$TARGET_DIR" >/dev/null 2>&1 || true
        sleep 1
    elif command -v lsof >/dev/null 2>&1; then
        PIDS=$(lsof -t +D "$TARGET_DIR" 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            echo -e "${YELLOW}Killing local processes with open files in $TARGET_DIR: $PIDS${RESET}"
            kill $PIDS 2>/dev/null || true
            sleep 1
            kill -9 $PIDS 2>/dev/null || true
        fi
    fi

    # Rather than requiring a full rm -rf to succeed before updating (which
    # blocks forever if a handle is held open on another machine), rename
    # the old install out of the way. A rename is just a metadata change on
    # the parent directory entry, so it succeeds even if files inside it
    # are still open elsewhere on the NFS share.
    OLD_DIR="${TARGET_DIR}.old.$(date +%s)"
    echo -e "${MAGENTA}Moving previous installation aside for update...${RESET}"
    mv "$TARGET_DIR" "$OLD_DIR"

    # Try to clean up the old copy in the background without blocking the
    # install. If it's still busy (remote handle), it's simply left behind
    # as leftover .nfsXXXXXXXX debris until that handle is released — it
    # doesn't stop the new installation from proceeding.
    ( rm -rf "$OLD_DIR" >/dev/null 2>&1 & )
fi

mkdir -p "$TARGET_DIR"

echo -e "${MAGENTA}Downloading $EDITOR_LABEL to $TMPFILE ...${RESET}"
curl -sSL "$DOWNLOAD_URL" -o "$TMPFILE"

echo -e "${MAGENTA}Extracting $EDITOR_LABEL...${RESET}"
tar -xzf "$TMPFILE" -C "$TARGET_DIR" --strip-components=1

echo -e "${MAGENTA}Cleaning up...${RESET}"
rm -f "$TMPFILE"

# Add PATH entry only if not already in rc file
if ! grep -q "$EDITOR_BIN_PATH" "$RC_FILE" 2>/dev/null; then
    echo -e "${BLUE}Adding $EDITOR_LABEL path to $RC_FILE${RESET}"
    {
        echo ""
        echo "# Add $EDITOR_LABEL to PATH"
        echo "export PATH=\"$EDITOR_BIN_PATH:\$PATH\""
    } >> "$RC_FILE"
else
    echo -e "${YELLOW}$EDITOR_LABEL path already present in $RC_FILE, skipping.${RESET}"
fi

# Locate the icon. VS Code and VSCodium ship it under the same relative
# path, but the filename itself can differ, so check both possibilities.
ICON_PATH=""
for candidate in "code.png" "codium.png" "vscodium.png"; do
    if [ -f "$TARGET_DIR/resources/app/resources/linux/$candidate" ]; then
        ICON_PATH="$TARGET_DIR/resources/app/resources/linux/$candidate"
        break
    fi
done
if [ -z "$ICON_PATH" ]; then
    echo -e "${YELLOW}Warning: could not find an icon under resources/app/resources/linux/.${RESET}"
    echo -e "${YELLOW}The desktop launcher will still be created, but the icon may not show.${RESET}"
    ICON_PATH="$TARGET_DIR/resources/app/resources/linux/code.png"
fi

# Create desktop entry
DESKTOP_FILE="$HOME/Desktop/${EDITOR_SUBDIR}.desktop"
DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=${EDITOR_LABEL}
Comment=Code Editing. Redefined.
Exec=${EDITOR_BIN_PATH}/${BIN_NAME} --no-sandbox %F
Icon=${ICON_PATH}
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=${STARTUP_WM_CLASS}"

mkdir -p "$HOME/Desktop"
echo -e "${BLUE}Creating desktop entry at $DESKTOP_FILE ...${RESET}"
echo "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Mark the .desktop file as trusted on GNOME/Nautilus so it doesn't
# show up as "untrusted" and require a manual right-click > Allow Launching
if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
fi

echo -e "${GREEN}\n✔ $EDITOR_LABEL installed in $TARGET_DIR${RESET}"
echo -e "${GREEN}Desktop launcher created: $DESKTOP_FILE${RESET}"

# Automatically apply the new PATH to the current terminal session.
# A plain `source "$RC_FILE"` here would only affect this script's own
# subshell and be lost the moment the script exits, so instead we
# `exec` a fresh login shell in its place. This replaces the script's
# process with a new shell that re-reads "$RC_FILE" itself, meaning
# the updated PATH shows up immediately in the same terminal window
# with no manual "source" step needed.
echo -e "${MAGENTA}Reloading shell to apply PATH changes...${RESET}"
exec "$SHELL" -l
