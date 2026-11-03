#!/usr/bin/env bash
# ==============================================================================
# Antigravity IDE Installer & Updater for Ubuntu / Linux
# Repository: https://github.com/David-mwas/antigravity-ide-update-script
# ==============================================================================
set -euo pipefail

# Resolve real user's home directory even if executed with sudo
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_HOME="$HOME"
fi

# Resolve XDG Downloads directory (fallback to ~/Downloads)
DOWNLOADS_DIR="${REAL_HOME}/Downloads"
if command -v xdg-user-dir >/dev/null 2>&1 && [[ -z "${SUDO_USER:-}" ]]; then
    DOWNLOADS_DIR=$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "${REAL_HOME}/Downloads")
fi

TARGET_DIR="/opt/antigravity"
DESKTOP_FILE="/usr/share/applications/antigravity-ide.desktop"
TAR_FILE=""
CLEAN_ARCHIVE=false
UNINSTALL=false

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[+]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

usage() {
    echo -e "${BOLD}Antigravity IDE Installer & Updater for Linux${NC}

${BOLD}Usage:${NC}
  $(basename "$0") [OPTIONS] [/path/to/Antigravity.tar.gz]

${BOLD}Options:${NC}
  -f, --file <path>      Path to a specific Antigravity .tar.gz archive
  -d, --dir <path>       Custom installation directory (default: /opt/antigravity)
  -c, --clean-archive    Delete the downloaded .tar.gz archive after successful install
  -u, --uninstall        Completely remove Antigravity IDE, symlinks, and desktop launcher
  -i, --install-self     Install this script globally to ~/.local/bin/update-antigravity
  -h, --help             Show this help message and exit

${BOLD}Examples:${NC}
  $(basename "$0")                                      # Auto-detect latest archive in Downloads
  $(basename "$0") ~/Downloads/\"Antigravity IDE.tar.gz\" # Install from a specific archive
  $(basename "$0") --clean-archive                      # Install and remove the .tar.gz afterward
  $(basename "$0") --uninstall                          # Uninstall Antigravity IDE"
}

install_self() {
    local bin_dir="${REAL_HOME}/.local/bin"
    mkdir -p "$bin_dir"
    cp "$0" "$bin_dir/update-antigravity"
    chmod +x "$bin_dir/update-antigravity"
    ln -sf "$bin_dir/update-antigravity" "$bin_dir/update-antigravity.sh"
    ok "Installed command to ${bin_dir}/update-antigravity"
    if [[ ":$PATH:" != *":${bin_dir}:"* ]]; then
        warn "${bin_dir} is not currently in your PATH. Add this to your ~/.bashrc or ~/.zshrc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            [[ $# -lt 2 ]] && err "Missing argument for $1"
            TAR_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            [[ $# -lt 2 ]] && err "Missing argument for $1"
            TARGET_DIR="$2"
            shift 2
            ;;
        -c|--clean-archive)
            CLEAN_ARCHIVE=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -i|--install-self)
            install_self
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            err "Unknown option: $1 (use --help for usage)"
            ;;
        *)
            TAR_FILE="$1"
            shift
            ;;
    esac
done

# Use sudo only if not already running as root
run_priv() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

extract_version() {
    local json_file="$1"
    if [[ -f "$json_file" ]]; then
        sed -n 's/.*"ideVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1
    fi
}

# Handle uninstall mode
if [[ "$UNINSTALL" == true ]]; then
    info "Uninstalling Antigravity IDE..."
    if [[ "$(id -u)" -ne 0 ]]; then sudo -v; fi
    if command -v snap >/dev/null 2>&1 && snap list antigravity >/dev/null 2>&1; then
        info "Removing Snap package..."
        run_priv snap remove antigravity
    fi
    run_priv rm -rf "$TARGET_DIR" /opt/antigravity-ide
    run_priv rm -f /usr/local/bin/antigravity /usr/local/bin/antigravity-ide
    run_priv rm -f "$DESKTOP_FILE" "${REAL_HOME}/.local/share/applications/antigravity.desktop" "${REAL_HOME}/.local/share/applications/antigravity-ide.desktop"
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_priv update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
    ok "Antigravity IDE has been uninstalled. (User settings in ~/.config and ~/.antigravity were preserved)."
    exit 0
fi

# 1. Verify required tools
for cmd in tar find sed grep; do
    command -v "$cmd" >/dev/null 2>&1 || err "Required command '$cmd' is not installed."
done

# 2. Locate tarball (passed as argument or newest in Downloads)
if [[ -z "$TAR_FILE" ]]; then
    info "Scanning $DOWNLOADS_DIR for the latest Antigravity archive..."
    TAR_FILE=$(find "$DOWNLOADS_DIR" -maxdepth 1 -type f \( -iname "*antigravity*.tar.gz" -o -iname "*antigravity*.tgz" -o -iname "*antigravity*.tar.xz" \) -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
fi

if [[ -z "$TAR_FILE" || ! -f "$TAR_FILE" ]]; then
    err "No Antigravity archive (.tar.gz / .tgz / .tar.xz) specified or found in $DOWNLOADS_DIR.\nRun '$(basename "$0") --help' for usage instructions."
fi

info "Selected archive: ${BOLD}${TAR_FILE}${NC}"

# Validate archive integrity before removing existing installation
info "Verifying archive integrity..."
if ! tar -tf "$TAR_FILE" >/dev/null 2>&1; then
    err "Archive '$TAR_FILE' appears to be corrupted or is not a valid tar archive. Aborting."
fi

# Check currently installed version if available
OLD_VER=$(extract_version "$TARGET_DIR/resources/app/product.json")
if [[ -n "$OLD_VER" ]]; then
    info "Currently installed version: ${BOLD}v${OLD_VER}${NC}"
fi

# 3. Request sudo privileges upfront if not root
if [[ "$(id -u)" -ne 0 ]]; then
    info "Requesting sudo permissions for installation..."
    sudo -v
fi

# 4. Remove conflicting Snap package if present
if command -v snap >/dev/null 2>&1 && snap list antigravity >/dev/null 2>&1; then
    warn "Removing conflicting Snap installation of antigravity..."
    run_priv snap remove antigravity
fi

# 5. Extract to a temporary staging directory on the same filesystem for atomic replacement
STAGE_DIR="${TARGET_DIR}.staging.$$"
cleanup_stage() {
    if [[ -d "$STAGE_DIR" ]]; then
        run_priv rm -rf "$STAGE_DIR"
    fi
}
trap cleanup_stage EXIT

info "Extracting archive to staging directory..."
run_priv rm -rf "$STAGE_DIR"
run_priv mkdir -p "$STAGE_DIR"

# Detect if the archive has a top-level wrapper directory
FIRST_ENTRY=$(tar -tf "$TAR_FILE" 2>/dev/null | head -n 1 || true)
STRIP_ARGS=()
if [[ "$FIRST_ENTRY" == */* ]]; then
    STRIP_ARGS=(--strip-components=1)
fi

run_priv tar -xf "$TAR_FILE" -C "$STAGE_DIR" "${STRIP_ARGS[@]}"

# 6. Fix ownership and permissions (including chrome-sandbox SUID bit for Ubuntu 23.10+/24.04+)
info "Configuring permissions and sandbox..."
run_priv chown -R root:root "$STAGE_DIR"
run_priv chmod -R +rX "$STAGE_DIR"
if [[ -f "$STAGE_DIR/chrome-sandbox" ]]; then
    run_priv chmod 4755 "$STAGE_DIR/chrome-sandbox"
fi

# 7. Replace target directory with staged installation
info "Installing to $TARGET_DIR..."
run_priv rm -rf "$TARGET_DIR"
run_priv mv "$STAGE_DIR" "$TARGET_DIR"

# 8. Create global CLI symlinks
EXEC_PATH=""
if [[ -f "$TARGET_DIR/bin/antigravity-ide" ]]; then
    EXEC_PATH="$TARGET_DIR/bin/antigravity-ide"
elif [[ -f "$TARGET_DIR/bin/antigravity" ]]; then
    EXEC_PATH="$TARGET_DIR/bin/antigravity"
elif [[ -f "$TARGET_DIR/antigravity-ide" ]]; then
    EXEC_PATH="$TARGET_DIR/antigravity-ide"
elif [[ -f "$TARGET_DIR/antigravity" ]]; then
    EXEC_PATH="$TARGET_DIR/antigravity"
fi

if [[ -n "$EXEC_PATH" ]]; then
    info "Linking CLI commands (/usr/local/bin/antigravity & antigravity-ide) -> $EXEC_PATH"
    run_priv chmod +x "$EXEC_PATH"
    run_priv mkdir -p /usr/local/bin
    run_priv ln -sf "$EXEC_PATH" /usr/local/bin/antigravity
    run_priv ln -sf "$EXEC_PATH" /usr/local/bin/antigravity-ide
else
    warn "Could not automatically locate main binary inside $TARGET_DIR."
fi

# 9. Detect application icon and register in system icon theme
ICON_PATH=""
if [[ -f "$TARGET_DIR/resources/app/resources/linux/code.png" ]]; then
    ICON_PATH="$TARGET_DIR/resources/app/resources/linux/code.png"
else
    ICON_PATH=$(find "$TARGET_DIR" -type f -name "*.png" | grep -E 'linux/code\.png|app\.png|logo\.png' | head -n 1 || true)
fi

if [[ -n "$ICON_PATH" && -f "$ICON_PATH" ]]; then
    run_priv mkdir -p /usr/share/pixmaps
    run_priv cp -f "$ICON_PATH" /usr/share/pixmaps/antigravity-ide.png
else
    ICON_PATH="text-editor"
fi

# 10. Create/Update Desktop Entry
info "Updating desktop launcher ($DESKTOP_FILE)..."
run_priv mkdir -p /usr/share/applications
cat << DESKTOP | run_priv tee "$DESKTOP_FILE" > /dev/null
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-Powered Code Editor
GenericName=Text Editor
Exec=/usr/local/bin/antigravity-ide %F
Icon=${ICON_PATH}
Type=Application
StartupNotify=true
StartupWMClass=Antigravity
Categories=TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;application/x-antigravity-ide-workspace;
Actions=new-empty-window;
Keywords=antigravity;code;editor;ide;ai;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=/usr/local/bin/antigravity-ide --new-window %F
Icon=${ICON_PATH}
DESKTOP

run_priv chmod 644 "$DESKTOP_FILE"

if command -v update-desktop-database >/dev/null 2>&1; then
    run_priv update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# 11. Optional cleanup of downloaded archive
if [[ "$CLEAN_ARCHIVE" == true ]]; then
    info "Removing archive: $TAR_FILE"
    rm -f "$TAR_FILE"
fi

# 12. Report new version
NEW_VER=$(extract_version "$TARGET_DIR/resources/app/product.json")
if [[ -n "$OLD_VER" && -n "$NEW_VER" ]]; then
    ok "Antigravity IDE updated successfully (${BOLD}v${OLD_VER} -> v${NEW_VER}${NC})!"
elif [[ -n "$NEW_VER" ]]; then
    ok "Antigravity IDE (${BOLD}v${NEW_VER}${NC}) installed and configured!"
else
    ok "Antigravity IDE installed and configured!"
fi
echo -e "    Launch from terminal: ${GREEN}antigravity .${NC} or ${GREEN}antigravity-ide${NC}"
