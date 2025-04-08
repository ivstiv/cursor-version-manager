#!/bin/sh

#H#
#H# cvm.sh — Cursor version manager
#H#
#H# Examples:
#H#   sh cvm.sh --list-local
#H#   ./cvm.sh --check
#H#   bash cvm.sh --use 0.40.4
#H#
#H# Notice*:
#H#   The AppImage files are downloaded from the official Cursor releases.
#H#   The list of download sources can be found at https://github.com/oslook/cursor-ai-downloads
#H#
#H# Options:
#H#   --list-local         Lists locally available versions
#H#   --list-remote        Lists versions available for download
#H#   --download <version> Downloads a version
#H#   --check              Check latest versions available for download
#H#   --update             Downloads and selects the latest version
#H#   --use <version>      Selects a locally available version
#H#   --active             Shows the currently selected version
#H#   --remove <version>   Removes a locally available version
#H#   --install            Adds an alias `cursor` and downloads the latest version
#H#   --uninstall          Removes the Cursor version manager directory and alias
#H#   --update-script      Updates the (cvm) script to the latest version
#H#   -v --version         Shows the script version
#H#   -h --help            Shows this message



#
# Constants
#
CURSOR_DIR="$HOME/.local/share/cvm"
DOWNLOADS_DIR="$CURSOR_DIR/app-images"
CVM_VERSION="1.2.0"
_CACHE_FILE="/tmp/cursor_versions.json"
VERSION_HISTORY_URL="https://raw.githubusercontent.com/oslook/cursor-ai-downloads/refs/heads/main/version-history.json"
GITHUB_API_URL="https://api.github.com/repos/ivstiv/cursor-version-manager/releases/latest"

#
# Functions
#
help() {
  sed -rn 's/^#H# ?//;T;p' "$0"
}

getLatestScriptVersion() {
  # Fetch latest release version from GitHub API
  latest_version=$(wget -qO- "$GITHUB_API_URL" | jq -r '.tag_name' 2>/dev/null)
  if [ -n "$latest_version" ]; then
    echo "$latest_version"
    return 0
  else
    return 1
  fi
}

getVersionHistory() {
  # Check if cache file exists and is less than 15 min old
  if [ -f "$_CACHE_FILE" ] && [ -n "$(find "$_CACHE_FILE" -mmin -15 2>/dev/null)" ]; then
    cat "$_CACHE_FILE"
    return 0
  fi

  # Fetch JSON directly from remote and cache it
  # echo "Fetching version history..." >&2
  if wget -qO "$_CACHE_FILE.tmp" "$VERSION_HISTORY_URL"; then
    mv "$_CACHE_FILE.tmp" "$_CACHE_FILE"
    cat "$_CACHE_FILE"
    return 0
  else
    rm -f "$_CACHE_FILE.tmp"
    echo "Error: Failed to fetch version history" >&2
    return 1
  fi
}

getRemoteVersions() {
  getVersionHistory | \
    jq -r '.versions[] | select(.platforms["linux-x64"] != null) | .version' \
      | sort -V
}

getLatestRemoteVersion() {
  getVersionHistory | \
    jq -r '.versions[] | select(.platforms["linux-x64"] != null) | .version' \
      | sort -V \
      | tail -n1
}

getLatestLocalVersion() {
  # shellcheck disable=SC2010
  ls -1 "$DOWNLOADS_DIR" \
    | grep -oP 'cursor-\K[0-9.]+(?=\.)' \
    | sort -r \
    | head -n 1
}

downloadVersion() {
  version=$1 # e.g. 2.1.0
  if [ -z "$version" ]; then
    echo "Error: Version number is required, use \`cvm --list-remote\` to see available versions" >&2
    return 1
  fi

  localFilename="cursor-$version.AppImage"
  url=$(
    getVersionHistory | \
      jq -r --arg v "$version" '.versions[] | select(.version == $v and .platforms["linux-x64"] != null) | .platforms["linux-x64"]'
  )
  echo "Downloading Cursor $version..."
  wget -O "$DOWNLOADS_DIR/$localFilename" "$url"
  chmod +x "$DOWNLOADS_DIR/$localFilename"
  echo "Cursor $version downloaded to $DOWNLOADS_DIR/$localFilename"
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
    downloadVersion "$latestRemoteVersion"
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
  printf "sed\ngrep\njq\nfind\nwget\n" | while IFS= read -r program; do
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

cleanupAppImages() {
  for build_file in "$DOWNLOADS_DIR"/cursor-*-build-*-x86_64.AppImage; do
    # Skip if no files match the pattern
    [ -e "$build_file" ] || continue
    
    # Extract version number from build file
    version=$(basename "$build_file" | sed -E 's/cursor-([0-9.]+)-build.*/\1/')
    regular_file="$DOWNLOADS_DIR/cursor-$version.AppImage"
    
    if [ -f "$regular_file" ]; then
      # If regular version exists, remove build version
      rm "$build_file"
      # echo "Removed build version for $version (regular version exists)"
    else
      # If only build version exists, rename it to regular format
      mv "$build_file" "$regular_file"
      # echo "Renamed build version to regular format for $version"
    fi
  done
}

updateScript() {
  version=$(getLatestScriptVersion)
  
  if [ -z "$version" ]; then
    echo "Error: Failed to determine version to download" >&2
    return 1
  fi
  
  # Get the download URL from the release assets
  download_url=$(
    wget -O- "$GITHUB_API_URL" \
      | jq -r '.assets[] | select(.name == "cvm.sh") | .browser_download_url'
  )
  
  if [ -z "$download_url" ]; then
    echo "Error: Failed to find download URL for cvm.sh" >&2
    return 1
  fi
  
  echo "Downloading CVM version ${version}..."
  
  # Download to a temporary file in the same directory
  script_dir=$(dirname "$0")
  temp_file="${script_dir}/cvm.sh.new"
  
  if wget -qO "$temp_file" "$download_url"; then
    chmod +x "$temp_file"
    mv "$temp_file" "$0"
    echo "Successfully updated to version ${version}"
    echo "Please run the script again to use the new version"
    return 0
  else
    rm -f "$temp_file"
    echo "Error: Failed to download version ${version}" >&2
    return 1
  fi
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
cleanupAppImages

case "$1" in
  --help|-h)
    help
    ;;
  --version|-v)
    echo "Current version: $CVM_VERSION"
    if latest_version=$(getLatestScriptVersion); then
      if [ "$latest_version" != "$CVM_VERSION" ]; then
        echo "Latest version available: $latest_version"
        echo "You can download the latest version with: $0 --update-script"
      else
        echo "You are running the latest version"
      fi
    else
      echo "Failed to check for latest version"
    fi
    ;;
  --update)
    latestVersion=$(getLatestRemoteVersion)
    downloadVersion "$latestVersion"
    selectVersion "$version"
    ;;
  --list-local)
    echo "Locally available versions:"
    # shellcheck disable=SC2010
    ls -1 "$DOWNLOADS_DIR" \
      | grep -oP 'cursor-\K[0-9.]+(?=\.)' \
      | sed 's/^/  - /'
    ;;
  --list-remote)
    echo "Remote versions:"
    getRemoteVersions | sed 's/^/  - /'
    ;;
  --download)
    version=$2
    if [ -z "$version" ]; then
      echo "Usage: $0 --download <version>"
      exit 1
    fi

    # check if version is available for download
    if ! getRemoteVersions | grep -q "^$version\$"; then
      echo "Version $version not found for download."
      exit 1
    fi

    # check if version is already downloaded
    if [ -f "$DOWNLOADS_DIR/cursor-$version.AppImage" ]; then
      echo "Version $version already downloaded."
    else
      downloadVersion "$version"
    fi
    echo "To select the downloaded version, run \`cvm --use $version\`"
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
    elif [ "$latestRemoteVersion" != "$activeVersion" ]; then
      echo "There is a newer version already installed!"
      echo "You can activate the latest version with \`cvm --use $latestRemoteVersion\`"
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
    version=$2c
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
  --update-script)
    updateScript
    ;;
  *)
    echo "Unknown command: $1"
    help
    exit 1
    ;;
esac