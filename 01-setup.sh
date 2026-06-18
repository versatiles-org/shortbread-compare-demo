#!/usr/bin/env bash
#
# 01-setup.sh — provision a Debian host: install Java 21, git, versatiles; clone the
# feature branch and build the planetiler distribution jar.
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

echo ">>> Installing system packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl wget git unzip gnupg apt-transport-https jq aria2

echo ">>> Installing Temurin (Eclipse) JDK 21"
if ! command -v java >/dev/null || ! java -version 2>&1 | grep -q '"21'; then
  sudo install -m 0755 -d /etc/apt/keyrings
  wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
  . /etc/os-release
  echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y temurin-21-jdk
fi
java -version

echo ">>> Installing the versatiles CLI"
if ! command -v versatiles >/dev/null; then
  # pick the right release asset for this OS/arch from the GitHub API (robust to naming changes)
  arch="$(uname -m)"   # x86_64 or aarch64
  asset_url="$(curl -fsSL https://api.github.com/repos/versatiles-org/versatiles-rs/releases/latest \
    | jq -r --arg a "$arch" '.assets[].browser_download_url
        | select(test("linux")) | select(test($a)) | select(test("gnu")) | select(endswith(".tar.gz"))' \
    | head -1)"
  if [ -z "$asset_url" ]; then
    echo "Could not find a versatiles linux/$arch release asset; install it manually from" >&2
    echo "https://github.com/versatiles-org/versatiles-rs/releases" >&2
    exit 1
  fi
  echo "    downloading $asset_url"
  tmp="$(mktemp -d)"
  curl -fsSL "$asset_url" | tar -xz -C "$tmp"
  sudo install -m 0755 "$(find "$tmp" -name versatiles -type f | head -1)" /usr/local/bin/versatiles
  rm -rf "$tmp"
fi
versatiles --version

echo ">>> Cloning $REPO_URL ($BRANCH)"
mkdir -p "$WORKDIR"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch origin "$BRANCH"
  git -C "$REPO_DIR" checkout "$BRANCH"
  git -C "$REPO_DIR" pull --ff-only
  git -C "$REPO_DIR" submodule update --init planetiler-openmaptiles
else
  # the openmaptiles submodule is required for the reactor build
  git clone --recurse-submodules --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

echo ">>> Building the planetiler distribution jar (this downloads Maven deps on first run)"
cd "$REPO_DIR"
./mvnw -q -pl planetiler-dist -am package -DskipTests
JAR="$(ls "$REPO_DIR"/planetiler-dist/target/*with-deps*.jar | head -1)"
echo ">>> Built: $JAR"
echo ">>> Setup complete. Next: ./02-generate.sh"
