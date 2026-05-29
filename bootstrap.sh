#!/usr/bin/env bash
#
# bootstrap.sh — install OpenJunto (the `oj` plugin) into a fresh
# environment for Claude Code, non-interactively. Safe to re-run.
#
# Does NOT require the repo to be cloned: by default it registers the
# public GitHub marketplace. If run from inside a checkout (or with
# OJ_SOURCE=local) it registers the local tree instead.
#
# Steps:
#   1. Ensure runtime deps: git + jq. jq is REQUIRED — without it the
#      SessionStart hook silently skips CONDUCTOR.md injection and the
#      manager protocol never loads. (gh is optional: issue-tracker only.)
#   2. Ensure the `claude` CLI is on PATH (installs the native build if absent).
#   3. Register the OpenJunto marketplace + install `oj` via `claude plugin …`
#      (prompt-free; writes extraKnownMarketplaces/enabledPlugins to settings).
#   4. Verify the plugin is registered.
#
# Env overrides (all optional):
#   OJ_SOURCE=github|local     Marketplace source. Default: local if this
#                              script sits in a checkout, else github.
#   OJ_SCOPE=user|project|local  Install scope. Default: user.
#   OJ_SKIP_CLAUDE_INSTALL=1   Don't try to install the claude CLI.
#   OJ_SKIP_DEPS=1             Don't try to install git/jq/curl.
#
# Auth: registering/installing the plugin needs NO Anthropic credentials
# (it just clones a public repo). RUNNING a session does — set
# ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN before you use claude.
#
# Exit codes: 0 ok | 1 hard failure | 2 usage error.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MARKET_NAME="openjunto"
MARKET_REPO="openjunto/oj-claude"
PLUGIN="oj@${MARKET_NAME}"
SCOPE="${OJ_SCOPE:-user}"

# ── logging (honor NO_COLOR and non-TTY) ────────────────────────────
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_b=$'\033[1m'; c_0=$'\033[0m'
else
  c_g=; c_y=; c_r=; c_b=; c_0=
fi
log()  { printf '%s==>%s %s\n'   "$c_b" "$c_0" "$*" >&2; }
ok()   { printf '%s ok %s %s\n'  "$c_g" "$c_0" "$*" >&2; }
warn() { printf '%swarn%s %s\n'  "$c_y" "$c_0" "$*" >&2; }
die()  { printf '%sERROR%s %s\n' "$c_r" "$c_0" "$*" >&2; exit 1; }

# ── source selection ────────────────────────────────────────────────
if [[ -z "${OJ_SOURCE:-}" ]]; then
  if [[ -f "${SELF_DIR}/.claude-plugin/marketplace.json" ]]; then
    OJ_SOURCE=local
  else
    OJ_SOURCE=github
  fi
fi
case "$OJ_SOURCE" in github|local) ;; *) die "OJ_SOURCE must be github|local (got '$OJ_SOURCE')" ;; esac
case "$SCOPE"     in user|project|local) ;; *) die "OJ_SCOPE must be user|project|local (got '$SCOPE')" ;; esac

# ── dependency install (best effort across package managers) ────────
pkg_install() {
  local sudo=
  [[ "${EUID:-$(id -u)}" -ne 0 ]] && command -v sudo >/dev/null 2>&1 && sudo=sudo
  if   command -v apt-get >/dev/null 2>&1; then $sudo apt-get update -qq && $sudo apt-get install -y "$@"
  elif command -v dnf     >/dev/null 2>&1; then $sudo dnf install -y "$@"
  elif command -v yum     >/dev/null 2>&1; then $sudo yum install -y "$@"
  elif command -v apk     >/dev/null 2>&1; then $sudo apk add --no-cache "$@"
  elif command -v pacman  >/dev/null 2>&1; then $sudo pacman -Syu --needed --noconfirm "$@"
  elif command -v zypper  >/dev/null 2>&1; then $sudo zypper -n install "$@"
  elif command -v brew    >/dev/null 2>&1; then brew install "$@"
  else return 1
  fi
}

ensure_dep() {  # ensure_dep <pkg> [binary]
  local pkg="$1" bin="${2:-$1}"
  if command -v "$bin" >/dev/null 2>&1; then ok "$pkg present ($(command -v "$bin"))"; return 0; fi
  [[ -n "${OJ_SKIP_DEPS:-}" ]] && die "$pkg missing and OJ_SKIP_DEPS is set"
  log "installing $pkg…"
  pkg_install "$pkg" || die "could not install '$pkg' automatically — install it and re-run"
  command -v "$bin" >/dev/null 2>&1 || die "'$pkg' still not found after install"
  ok "$pkg installed"
}

ensure_claude() {
  if command -v claude >/dev/null 2>&1; then ok "claude present ($(command -v claude))"; return 0; fi
  if [[ -x "$HOME/.local/bin/claude" ]]; then
    export PATH="$HOME/.local/bin:$PATH"; ok "claude found at ~/.local/bin"; return 0
  fi
  [[ -n "${OJ_SKIP_CLAUDE_INSTALL:-}" ]] && die "claude not on PATH and OJ_SKIP_CLAUDE_INSTALL is set"
  log "installing the Claude Code CLI (native build → ~/.local/bin)…"
  local installer="https://claude.ai/install.sh" netfail="failed to download/run the Claude installer — check network/proxy/DNS, or install claude manually and re-run"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$installer" | bash || die "$netfail"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$installer" | bash || die "$netfail"
  else
    ensure_dep curl
    curl -fsSL "$installer" | bash || die "$netfail"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  command -v claude >/dev/null 2>&1 || die "claude still not on PATH — add ~/.local/bin to PATH and re-run"
  local ver
  ver="$(claude --version 2>&1)" \
    || die "claude installed but won't run — likely missing shared libs (Alpine/musl: apk add libstdc++ libgcc gcompat). Loader said: $ver"
  ok "claude installed ($ver)"
}

# ── plugin registration + install (idempotent) ──────────────────────
register_marketplace() {
  local mlist
  mlist="$(claude plugin marketplace list --json 2>/dev/null || true)"
  if [[ -n "$mlist" ]] && jq -e --arg n "$MARKET_NAME" 'any(.. | objects; .name? == $n)' >/dev/null 2>&1 <<<"$mlist"; then
    ok "marketplace '$MARKET_NAME' already registered"; return 0
  fi
  local src out
  case "$OJ_SOURCE" in
    local)  src="$SELF_DIR" ;;
    github) src="$MARKET_REPO" ;;
  esac
  log "registering $OJ_SOURCE marketplace: $src"
  if ! out="$(claude plugin marketplace add "$src" --scope "$SCOPE" 2>&1)"; then
    grep -qi 'already' <<<"$out" \
      || { printf '%s\n' "$out" >&2; die "marketplace add failed (network? git? private repo needs GITHUB_TOKEN?)"; }
  fi
  ok "marketplace registered"
}

install_plugin() {
  log "installing plugin $PLUGIN (scope=$SCOPE)…"
  local out
  if out="$(claude plugin install "$PLUGIN" --scope "$SCOPE" 2>&1)"; then
    ok "plugin installed"
  elif grep -Eqi 'already (installed|present|exist)' <<<"$out"; then
    claude plugin enable "$PLUGIN" --scope "$SCOPE" >/dev/null 2>&1 || true
    ok "plugin already present — ensured enabled (verify() confirms below)"
  else
    printf '%s\n' "$out" >&2; die "plugin install failed"
  fi
}

verify() {
  log "verifying…"
  if command -v jq >/dev/null 2>&1; then ok "jq $(jq --version)"
  else warn "jq missing — CONDUCTOR.md injection will be skipped; the manager protocol will NOT load"; fi
  # Authoritative gate: a failed/unhealthy install must NOT reach the success
  # banner. Prefer structured --json (exact id + enabled + no load errors);
  # fall back to an anchored text match on older CLIs.
  local json
  json="$(claude plugin list --json 2>/dev/null || true)"
  if [[ -n "$json" ]] && jq -e . >/dev/null 2>&1 <<<"$json"; then
    if jq -e --arg p "$PLUGIN" \
         'any(.. | objects | select(.id? == $p); (.enabled // true) and ((.errors // []) | length == 0))' \
         >/dev/null <<<"$json"; then
      ok "'$PLUGIN' is installed and healthy"; return 0
    fi
    if jq -e --arg p "$PLUGIN" 'any(.. | objects; .id? == $p)' >/dev/null <<<"$json"; then
      jq -r --arg p "$PLUGIN" \
        '.. | objects | select(.id? == $p) | "  enabled=\(.enabled) errors=\(.errors // [])"' \
        <<<"$json" >&2
      die "'$PLUGIN' is present but unhealthy (disabled or failed to load) — see status above"
    fi
    printf '%s\n' "$json" >&2
    die "'$PLUGIN' not found in 'claude plugin list' — install did not complete"
  fi

  local list
  list="$(claude plugin list 2>/dev/null || true)"
  if grep -Eqi "(^|[^a-z0-9_-])oj@${MARKET_NAME}([^a-z0-9_-]|$)" <<<"$list"; then
    ok "'$PLUGIN' is registered with Claude Code"
  else
    printf '%s\n' "$list" >&2
    die "could not confirm '$PLUGIN' in 'claude plugin list' — install did not complete"
  fi
}

# ── run ─────────────────────────────────────────────────────────────
log "OpenJunto bootstrap — source=$OJ_SOURCE scope=$SCOPE"
ensure_dep git
ensure_dep jq
ensure_claude
register_marketplace
install_plugin
verify

CLAUDE_BIN="$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")"
cat >&2 <<EOF

${c_b}OpenJunto installed.${c_0} Next:
  • claude is at: ${CLAUDE_BIN}
    Non-interactive shells (ssh 'claude …', systemd, CI) may not source your
    shell rc — if so, export PATH first:
        export PATH="\$HOME/.local/bin:\$PATH"
  • Provide credentials before starting a session:
      export ANTHROPIC_API_KEY=...          # Console API key, or
      export CLAUDE_CODE_OAUTH_TOKEN=...     # from \`claude setup-token\` on a desktop
  • Start a session — on stderr you should see:
      OpenJunto v<version> active …
  • Headless first run (force synchronous plugin load + surface load errors):
      CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude -p "ping" \\
        --output-format stream-json --verbose \\
        | jq 'select(.subtype=="init") | {plugins, plugin_errors}'
  • Inside a session, probe runtime health:  /oj:health-check
EOF
