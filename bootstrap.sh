#!/usr/bin/env bash
#
# LagoonAtHome bootstrap — clones the repo and hands off to install.sh.
# Designed to run via:  curl -fsSL <url> | bash
#
# Environment overrides:
#   LAGOON_HOME      Target directory (default: $HOME/LagoonAtHome)
#   LAGOON_VERSION   Git ref to check out (default: main)
#   LAGOON_REPO      Clone source (default: https://github.com/LagoonAtHome/LagoonAtHome.git)

set -euo pipefail

REPO="${LAGOON_REPO:-https://github.com/LagoonAtHome/LagoonAtHome.git}"
REF="${LAGOON_VERSION:-main}"
DEST="${LAGOON_HOME:-$HOME/LagoonAtHome}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[bootstrap]${NC} $*"; }
ok()    { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bootstrap]${NC} $*"; }
fatal() { echo -e "${RED}[bootstrap]${NC} $*" >&2; exit 1; }

# install.sh prompts the user — we need a real terminal on stdin even when piped via curl.
if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
    fatal "No interactive terminal available. Re-run from an SSH or local shell, or clone the repo and run ./install.sh directly."
fi

for cmd in git curl; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "$cmd is required but not installed."
done

# Fetch or update.
if [ -d "$DEST/.git" ]; then
    info "Existing checkout at $DEST — fetching $REF"
    git -C "$DEST" fetch --tags --quiet origin
    git -C "$DEST" checkout --quiet "$REF"
    git -C "$DEST" pull --ff-only --quiet || warn "Could not fast-forward — leaving checkout as-is"
elif [ -e "$DEST" ]; then
    fatal "$DEST exists but is not a git checkout. Move or remove it and retry."
else
    info "Cloning $REPO ($REF) into $DEST"
    git clone --quiet --branch "$REF" "$REPO" "$DEST"
fi

ok "Repository ready at $DEST"
cd "$DEST"

# Run install.sh with stdin attached to the terminal so prompts work
# even when bootstrap was invoked via curl | bash (which leaves stdin
# wired to the curl pipe).
if [ -e /dev/tty ] && [ ! -t 0 ]; then
    info "Handing off to install.sh"
    exec ./install.sh "$@" </dev/tty
else
    info "Handing off to install.sh"
    exec ./install.sh "$@"
fi
