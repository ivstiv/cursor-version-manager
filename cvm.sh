#!/bin/sh

#H#
#H# cvm.sh — Cursor version manager
#H#
#H# Examples:
#H#   sh cvm.sh --list-local
#H#   ./cvm.sh --check
#H#   bash cvm.sh --use 0.40.4
#H#
#H# Options:
#H#   --list-local       Lists locally available versions
#H#   --check            Check latest versions available for download
#H#   --update           Downloads and selects the latest version
#H#   --use <version>    Selects a locally available version
#H#   --active           Shows the currently selected version
#H#   --remove <version> Removes a locally available version
#H#   --install          Adds an alias `cursor` and downloads the latest version
#H#   --uninstall        Removes the Cursor version manager directory and alias
#H#   -v --version       Shows the script version
#H#   -h --help          Shows this message



#
# Constants
#
CURSOR_DIR="$HOME/.local/share/cvm"
DOWNLOADS_DIR="$CURSOR_DIR/app-images"
CVM_VERSION="1.0.0"



#
# Functions
#
help() {
  sed -rn 's/^#H# ?//;T;p' "$0"
}

getLatestRemoteVersion() {
  curl -s -r 0-0 \
    https://downloader.cursor.sh/linux/appImage/x64 \
    -o /dev/null -D - \
    | grep -oP 'filename="cursor-\K[0-9.]+'
}

getLatestLocalVersion() {
  # shellcheck disable=SC2010
  ls -1 "$DOWNLOADS_DIR" \
    | grep -oP 'cursor-\K[0-9.]+(?=\.)' \
    | sort -r \
    | head -n 1
}

downloadLatest() {
  version=$1 # e.g. 2.1.0
  filename="cursor-$version.AppImage"
  url="https://downloader.cursor.sh/linux/appImage/x64"
  echo "Downloading Cursor $version..."
  curl -L "$url" -o "$DOWNLOADS_DIR/$filename"
  chmod +x "$DOWNLOADS_DIR/$filename"
  echo "Cursor $version downloaded to $DOWNLOADS_DIR/$filename"
}

selectVersion() {
  version=$1 # e.g. 2.1.0
  filename="cursor-$version.AppImage"
  appimage_path="$DOWNLOADS_DIR/$filename"
  ln -sf "$appimage_path" "$CURSOR_DIR/active"
  echo "Symlink created: $CURSOR_DIR/active -> $appimage_path"
}

getActiveVersion() {
  if [ -L "$CURSOR_DIR/active" ]; then
    appimage_path=$(readlink -f "$CURSOR_DIR/active")
    version=$(basename "$appimage_path" | sed -E 's/cursor-([0-9.]+)\.AppImage/\1/')
    echo "$version"
  else
    echo "No active version. Use \`cvm --use <version>\` to select one."
    exit 1
  fi
}

exitIfVersionNotInstalled() {
  version=$1
  appimage_path="$DOWNLOADS_DIR/cursor-$version.AppImage"
  if [ ! -f "$appimage_path" ]; then
    echo "Version $version not found locally. Use \`cvm --list-local\` to list available versions."
    exit 1
  fi
}

installCVM() {
  latestRemoteVersion=$(getLatestRemoteVersion)
  latestLocalVersion=$(getLatestLocalVersion)
  if [ "$latestRemoteVersion" != "$latestLocalVersion" ]; then
    downloadLatest "$latestRemoteVersion"
  fi
  selectVersion "$latestRemoteVersion"

  echo "Cursor $latestRemoteVersion installed and activated."
  echo "Adding alias to your shell config..."
  case "$(basename "$SHELL")" in
    sh|dash)
      if ! grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.profile"; then
        echo "alias cursor='$CURSOR_DIR/active'" >> "$HOME/.profile"
      fi
      ;;
    bash)
      if ! grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.bashrc"; then
        echo "alias cursor='$CURSOR_DIR/active'" >> "$HOME/.bashrc"
      fi
      ;;
    zsh)
      if ! grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.zshrc"; then
        echo "alias cursor='$CURSOR_DIR/active'" >> "$HOME/.zshrc"
      fi
      ;;
  esac
  echo "Alias added. You can now use 'cursor' to run Cursor."
  case "$(basename "$SHELL")" in
    sh|dash)
      echo "Run '. ~/.profile' to apply the changes or restart your shell."
      ;;
    bash)
      echo "Run 'source ~/.bashrc' to apply the changes or restart your shell."
      ;;
    zsh)
      echo "Run 'source ~/.zshrc' to apply the changes or restart your shell."
      ;;
  esac
}

uninstallCVM() {
  rm -rf "$CURSOR_DIR"
  case "$(basename "$SHELL")" in
    sh|dash)
      if grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.profile"; then
        sed -i "\#alias cursor='$CURSOR_DIR/active'#d" "$HOME/.profile"
        echo "Alias removed from ~/.profile"
        echo "Run '. ~/.profile' to apply the changes or restart your shell."
      fi
      ;;
    bash)
      if grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.bashrc"; then
        sed -i "\#alias cursor='$CURSOR_DIR/active'#d" "$HOME/.bashrc"
        echo "Alias removed from ~/.bashrc"
        echo "Run 'source ~/.bashrc' to apply the changes or restart your shell."
      fi
      ;;
    zsh)
      if grep -q "alias cursor='$CURSOR_DIR/active'" "$HOME/.zshrc"; then
        sed -i "\#alias cursor='$CURSOR_DIR/active'#d" "$HOME/.zshrc"
        echo "Alias removed from ~/.zshrc"
        echo "Run 'source ~/.zshrc' to apply the changes or restart your shell."
      fi
      ;;
  esac
  echo "Cursor version manager uninstalled."
}

checkDependencies() {
  mainShellPID="$$"
  printf "sed\ncurl\ngrep\n" | while IFS= read -r program; do
    if ! [ -x "$(command -v "$program")" ]; then
      echo "Error: $program is not installed." >&2
      kill -9 "$mainShellPID" 
    fi
  done
}

isShellSupported() {
  case "$(basename "$SHELL")" in
    sh|dash|bash|zsh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}



#
# Execution
#
if ! isShellSupported; then
  echo "Error: Unsupported shell. Please use bash, zsh, or sh."
  echo "Currently using: $(basename "$SHELL")"
  echo "Open a github issue if you want to add support for your shell:"
  echo "https://github.com/ivstiv/cursor-version-manager/issues"
  exit 1
fi

checkDependencies
mkdir -p "$DOWNLOADS_DIR"

case "$1" in
  --help|-h)
    help
    ;;
  --version|-v)
    echo "$CVM_VERSION"
    ;;
  --update)
    latestVersion=$(getLatestRemoteVersion)
    downloadLatest "$latestVersion"
    selectVersion "$version"
    ;;
  --list-local)
    echo "Locally available versions:"
    # shellcheck disable=SC2010
    ls -1 "$DOWNLOADS_DIR" \
      | grep -oP 'cursor-\K[0-9.]+(?=\.)' \
      | sed 's/^/  - /'
    ;;
  --check)
    latestRemoteVersion=$(getLatestRemoteVersion)
    latestLocalVersion=$(getLatestLocalVersion)
    activeVersion=$(getActiveVersion)
    echo "Latest remote version: $latestRemoteVersion"
    echo "Latest locally available: $latestLocalVersion"
    echo "Currently active: $activeVersion"

    if [ "$latestRemoteVersion" != "$latestLocalVersion" ]; then
      echo "There is a newer version available for download!"
      echo "You can activate the latest version with \`cvm --update\`"
    else
      echo "Already up to date."
    fi
    ;;
  --active)
    getActiveVersion
    ;;
  --use)
    version=$2
    if [ -z "$version" ]; then
      echo "Usage: $0 --use <version>"
      exit 1
    fi

    exitIfVersionNotInstalled "$version"
    selectVersion "$version"
    ;;
  --remove)
    version=$2
    if [ -z "$version" ]; then
      echo "Usage: $0 --remove <version>"
      exit 1
    fi

    exitIfVersionNotInstalled "$version"
    activeVersion=$(getActiveVersion)

    if [ "$activeVersion" = "$version" ]; then
      rm "$CURSOR_DIR/active"
    fi
    rm "$DOWNLOADS_DIR/cursor-$version.AppImage"
    ;;
  --install)
    installCVM
    ;;
  --uninstall)
    uninstallCVM
    ;;
  *)
    echo "Unknown command: $1"
    help
    exit 1
    ;;
esac