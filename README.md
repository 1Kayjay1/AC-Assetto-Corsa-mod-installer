# 🏎️ Assetto Corsa Mod Installer

**The easiest way to install Assetto Corsa mods.** Just drag, drop, and drive!

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)

---

## ✨ Features

- **🎯 Smart Detection** - Automatically identifies cars, tracks, apps, CSP extensions, PP filters, Pure scripts, and more
- **📦 Archive Support** - Handles `.zip`, `.rar`, and `.7z` files directly
- **⚠️ Conflict Resolution** - Detects duplicate files and lets you choose which to keep
- **↩️ Undo Capability** - Test installations safely with instant rollback
- **🔍 Preview Mode** - See exactly what will be installed before committing
- **🚀 One-Click Install** - No manual folder navigation required

---

## 📥 Installation

1. **Download** `install_ac_mod.ps1` from this repository
2. **Place it** anywhere convenient (e.g., your Desktop or Downloads folder)
3. **Run it** by right-clicking → "Run with PowerShell"

> **First Run:** The script will ask you to select your Assetto Corsa installation folder. This is saved for future use.

---

## 🎮 Usage

### Method 1: Run the Script
1. Double-click `install_ac_mod.ps1` or right-click → "Run with PowerShell"
2. Select your mod (folder or archive)
3. Review the installation plan
4. Press `Y` to install

### Method 2: Drag & Drop (Coming Soon)
Drag a mod folder or archive directly onto the script file.

---

## 🔧 What It Detects

| Mod Type | Detection Method | Destination |
|----------|-----------------|-------------|
| **Cars** | `ui_car.json` or `data/` folder | `content/cars/` |
| **Tracks** | `ui_track.json` or `ui/ui_track.json` | `content/tracks/` |
| **Python Apps** | `apps/python/` structure | `apps/python/` |
| **Lua Apps** | `apps/lua/` structure | `apps/lua/` |
| **CSP Tools** | `extension/lua/tools/` | `extension/lua/tools/` |
| **CSP Modes** | `extension/lua/new-modes/` | `extension/lua/new-modes/` |
| **CSP Cameras** | `extension/lua/chaser-camera/` | `extension/lua/chaser-camera/` |
| **CSP Assists** | `extension/lua/joypad-assist/` | `extension/lua/joypad-assist/` |
| **CSP Weather** | `extension/weather/` | `extension/weather/` |
| **PP Filters** | INI with `[PP_BUILD]` or `[POST_PROCESS]` | `system/cfg/ppfilters/` |
| **Pure Scripts** | Lua files with Pure patterns | `system/cfg/ppfilters/pure_scripts/` |
| **CSP Configs** | INI with `[SHADER_REPLACEMENT]` | `extension/config/` |

---

## 🛡️ Safety Features

### Conflict Detection
When multiple files would install to the same location, you'll be prompted:
```
[!] CONFLICT: Multiple sources for extension\config\ext_config.ini
1. [CSP Config] ext_config.ini (from ModPack1)
2. [CSP Config] ext_config.ini (from ModPack2)
Select source (1-2):
```

### Undo Mode (Testing)
After installation, you can instantly undo all changes:
```
[TESTING MODE]
1. KEEP Changes (Delete Backup)
2. UNDO Changes (Restore Backup)
Choice: 2
```

---

## 📋 Requirements

- **Windows 10/11**
- **PowerShell 5.1+** (pre-installed on Windows 10+)
- **Assetto Corsa** (Steam or standalone)
- **Optional:** WinRAR or 7-Zip for `.rar`/`.7z` support

---

## ❓ FAQ

### How do I change my Assetto Corsa path?
Delete the `ac_path.txt` file in the same folder as the script, then run again.

### Why are some files shown as "Root Merge"?
These are files in standard AC folders (like `extension/textures/`) that will be merged directly into your installation.

### Can I install multiple mods at once?
Put all your mods in one folder and select that folder. The script will detect and install all of them.

---

## 🤝 Contributing

Found a bug or have a suggestion? Open an issue or submit a PR!

---

## 📜 License

MIT License - Feel free to use, modify, and share!

---

**Made with ❤️ for the Assetto Corsa community**
