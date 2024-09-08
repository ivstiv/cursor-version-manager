# Cursor Version Manager

A shell script to manage multiple versions of Cursor locally on your machine. **Built for linux users that use the AppImage distribution of Cursor.**

### Installation

1. Download the script
```bash
wget -O - https://github.com/ivstiv/cursor-version-manager/archive/main.tar.gz | tar -xz --strip=1 "cursor-version-manager-main/cvm.sh"
```

2. Make the script executable (optional)

```bash
chmod +x cvm.sh
```

3. Download the latest Cursor AppImage and add an alias to it
```bash
./cvm.sh --install
```

### Usage
```bash
cvm.sh — Cursor version manager

Examples:
  sh cvm.sh --list-local
  ./cvm.sh --check
  bash cvm.sh --use 0.40.4

Options:
  --list-local       Lists locally available versions
  --check            Check latest versions available for download
  --update           Downloads and selects the latest version
  --use <version>    Selects a locally available version
  --active           Shows the currently selected version
  --remove <version> Removes a locally available version
  --install          Adds an alias `cursor` and downloads the latest version
  --uninstall        Removes the Cursor version manager directory and alias
  -v --version       Shows the script version
  -h --help          Shows this message
```