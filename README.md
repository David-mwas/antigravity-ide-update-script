<div align="center">
  <img src="assets/banner.jpg" alt="Antigravity IDE for Linux Banner" width="100%" />

  <h1>Antigravity IDE Installer & Updater for Linux</h1>
  <p><strong>Zero-dependency Bash automation to cleanly install, update, or uninstall Antigravity IDE from official <code>.tar.gz</code> archives on Ubuntu, Debian, and other Linux distributions.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Platform: Linux | Ubuntu" />
    <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Shell: Bash" />
    <img src="https://img.shields.io/badge/License-MIT-00B4D8?style=for-the-badge" alt="License: MIT" />
  </p>
</div>

---

Instead of manually extracting archives, fixing `chrome-sandbox` permissions, recreating symlinks, and configuring `.desktop` launchers every time a new version is released, run a single command.

## ✨ Features

- **Auto-Detection:** Automatically locates the newest `*Antigravity*.tar.gz` archive in your `~/Downloads` directory (respecting XDG user directories and `sudo` invocations).
- **Safe Atomic Updates:** Verifies archive integrity and extracts to a temporary staging folder first—your existing installation is never broken if an archive is corrupted or interrupted.
- **Ubuntu 23.10 / 24.04+ AppArmor & Sandbox Ready:** Automatically sets `root:root` ownership and `4755` SUID permissions on `chrome-sandbox` so Electron launches without sandbox errors.
- **Conflict Resolution:** Detects and removes conflicting `antigravity` Snap installations that shadow `/usr/local/bin` in `$PATH`.
- **CLI Integration:** Links both `antigravity` and `antigravity-ide` to `/usr/local/bin` via the official CLI wrapper so `antigravity .` works cleanly from any terminal.
- **Desktop & Icon Integration:** Installs the official application icon and registers `/usr/share/applications/antigravity-ide.desktop` (with a *"New Empty Window"* right-click action).
- **Version Tracking:** Displays the exact version upgrade path (e.g., `v2.5.0 -> v2.6.0`).

---

## 🚀 Quick Start

### 1. Clone the repository & install the command globally

```bash
git clone https://github.com/David-mwas/antigravity-ide-update-script.git
cd antigravity-ide-update-script
chmod +x update-antigravity.sh
./update-antigravity.sh --install-self
```

This installs the `update-antigravity` command into `~/.local/bin/update-antigravity`.

---

## 📖 Usage

### Automatic Update (Recommended)
1. Download the latest **Antigravity IDE** `.tar.gz` archive into your `~/Downloads` folder.
2. Run:

```bash
update-antigravity
```

### Install from a Specific Archive Path
```bash
update-antigravity ~/Downloads/"Antigravity IDE (1).tar.gz"
```

### Install & Delete Archive Afterward
To save disk space by automatically deleting the `.tar.gz` file once the update succeeds:
```bash
update-antigravity --clean-archive
```

### Uninstall Antigravity IDE
To cleanly remove `/opt/antigravity`, CLI symlinks, and the desktop entry (while preserving your user settings and extensions in `~/.config` and `~/.antigravity-ide`):
```bash
update-antigravity --uninstall
```

---

## ⚙️ All Command-Line Options

```text
Usage:
  update-antigravity [OPTIONS] [/path/to/Antigravity.tar.gz]

Options:
  -f, --file <path>      Path to a specific Antigravity .tar.gz archive
  -d, --dir <path>       Custom installation directory (default: /opt/antigravity)
  -c, --clean-archive    Delete the downloaded .tar.gz archive after successful install
  -u, --uninstall        Completely remove Antigravity IDE, symlinks, and desktop launcher
  -i, --install-self     Install this script globally to ~/.local/bin/update-antigravity
  -h, --help             Show this help message and exit
```

---

## 🐧 Compatibility

Tested and compatible with:
- **Ubuntu** (20.04 LTS, 22.04 LTS, 24.04 LTS, and newer)
- **Linux Mint / Pop!_OS / Debian**
- **Fedora / Arch / openSUSE** (any systemd/XDG-compliant Linux desktop)

---

## 📄 License

MIT License
