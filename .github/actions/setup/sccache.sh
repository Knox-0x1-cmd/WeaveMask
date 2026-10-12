#!/usr/bin/env bash
set -euo pipefail

# Get latest sccache version (authenticated when GH_TOKEN is available to
# avoid the 60 req/hour unauthenticated rate limit on shared runner IPs).
get_sccache_ver() {
  local auth=()
  if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    auth=(-H "Authorization: Bearer ${GH_TOKEN:-${GITHUB_TOKEN}}")
  fi
  curl -fsSL --retry 3 --connect-timeout 15 "${auth[@]}" 'https://api.github.com/repos/mozilla/sccache/releases/latest' | jq -r .tag_name
}

# $1=variant
# $2=install_dir
# $3=exe
install_from_gh() {
  local ver
  ver=$(get_sccache_ver)
  if [ -z "$ver" ] || [ "$ver" = "null" ]; then
    echo "Failed to resolve latest sccache version" >&2
    exit 1
  fi
  local url="https://github.com/mozilla/sccache/releases/download/${ver}/sccache-${ver}-$1.tar.gz"
  local dest="$2/$3"
  mkdir -p "$2"
  # Fail on HTTP errors; don't leave a half-written binary behind.
  curl -fsSL --retry 3 --connect-timeout 15 "$url" | tar xz -O --wildcards "*/$3" > "$dest.tmp"
  trap 'rm -f "$dest.tmp"' EXIT
  mv "$dest.tmp" "$dest"
  trap - EXIT
  chmod +x "$dest"
}

# Exported so `sudo bash -c` can reuse it (functions don't survive sudo).
export -f get_sccache_ver install_from_gh

if [ "${RUNNER_OS:-}" = "macOS" ]; then
  if ! command -v sccache >/dev/null 2>&1; then
    brew install sccache
  fi
  sccache --version
elif [ "${RUNNER_OS:-}" = "Linux" ]; then
  if [ -w /usr/local/bin ]; then
    install_from_gh x86_64-unknown-linux-musl /usr/local/bin sccache
  elif command -v sudo >/dev/null 2>&1; then
    sudo -E bash -c 'install_from_gh x86_64-unknown-linux-musl /usr/local/bin sccache'
  else
    # Fallback for runners without sudo: user-local install + PATH.
    mkdir -p "$HOME/.local/bin"
    install_from_gh x86_64-unknown-linux-musl "$HOME/.local/bin" sccache
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
    export PATH="$HOME/.local/bin:$PATH"
  fi
elif [ "${RUNNER_OS:-}" = "Windows" ]; then
  # Git Bash: $USERPROFILE may contain backslashes; $HOME is already POSIX.
  _dest="$HOME/.cargo/bin"
  mkdir -p "$_dest"
  install_from_gh x86_64-pc-windows-msvc "$_dest" sccache.exe
  echo "$_dest" >> "$GITHUB_PATH"
  export PATH="$_dest:$PATH"
else
  echo "Unsupported RUNNER_OS: ${RUNNER_OS:-<unset>}" >&2
  exit 1
fi
