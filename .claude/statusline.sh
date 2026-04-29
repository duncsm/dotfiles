#!/bin/bash
# Claude Code status line — Catppuccin Mocha powerline style
# Receives JSON session data on stdin, prints a single colored line
# Requires a Nerd Font (e.g. any Nerd Font patched terminal font)
#
# Setup:
#   1. Save this file to ~/.claude/statusline.sh
#   2. chmod +x ~/.claude/statusline.sh
#   3. Add to ~/.claude/settings.json:
#      {
#        "statusLine": {
#          "type": "command",
#          "command": "~/.claude/statusline.sh",
#          "padding": 0
#        }
#      }
#   4. Restart Claude Code — the bar appears at the bottom of your terminal
#
# Segments (left to right):
#   [model] [git branch +staged ~modified] [context bar % $cost duration] [output style] [agent] [vim mode]
#
# Dependencies: jq, git, awk, md5/md5sum

input=$(cat)

# Catppuccin Mocha — truecolor ANSI
BG_BLUE='\033[48;2;137;180;250m'
BG_GREEN='\033[48;2;166;227;161m'
BG_YELLOW='\033[48;2;249;226;175m'
BG_MAUVE='\033[48;2;203;166;247m'
BG_TEAL='\033[48;2;148;226;213m'
BG_PEACH='\033[48;2;250;179;135m'
FG_BASE='\033[38;2;30;30;46m'
FG_DIM='\033[38;2;108;112;134m'   # Catppuccin Mocha overlay0 — for empty bar portion

# Foreground versions of segment bg colors — used for powerline arrow transitions
FG_BLUE='\033[38;2;137;180;250m'
FG_GREEN='\033[38;2;166;227;161m'
FG_YELLOW='\033[38;2;249;226;175m'
FG_MAUVE='\033[38;2;203;166;247m'
FG_TEAL='\033[38;2;148;226;213m'
FG_PEACH='\033[38;2;250;179;135m'

BOLD='\033[1m'
RESET='\033[0m'

# Nerd Font powerline glyphs
SEP=$(printf '\xee\x82\xb0')     # U+E0B0 right-arrow
CAP_L=$(printf '\xee\x82\xb6')  # U+E0B6 left rounded cap
CAP_R=$(printf '\xee\x82\xb4')  # U+E0B4 right rounded cap
CHIP=$(printf '\xef\x8b\x9b')   # U+F2DB fa-microchip
BRANCH=$(printf '\xee\x82\xa0') # U+E0A0 Powerline VCS branch
ROBOT=$(printf '\xef\x95\x84')  # U+F544 fa-robot

# Extract all fields in one jq call (unit separator to handle empty fields)
IFS=$'\x1f' read -r MODEL DIR CUR_DIR PCT COST VIM_MODE DURATION_MS STYLE AGENT TOTAL_INPUT TOTAL_OUTPUT CUR_CACHE_READ CUR_CACHE_CREATE CTX_SIZE REMAINING_PCT SESSION_ID < <(
  echo "$input" | jq -r '[
    (.model.display_name // "claude"),
    (.workspace.project_dir // .workspace.current_dir // ""),
    (.workspace.current_dir // ""),
    ((.context_window.used_percentage // 0) | floor | tostring),
    (.cost.total_cost_usd // 0 | tostring),
    (.vim.mode // ""),
    (.cost.total_duration_ms // 0 | tostring),
    (.output_style.name // "default"),
    (.agent.name // ""),
    (.context_window.total_input_tokens // 0 | tostring),
    (.context_window.total_output_tokens // 0 | tostring),
    (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
    (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
    (.context_window.context_window_size // 200000 | tostring),
    ((.context_window.remaining_percentage // 100) | floor | tostring),
    (.session_id // "unknown")
  ] | join("\u001f")'
)

# Git status — cached to avoid lag on large repos
CACHE_DIR_KEY=$(printf '%s' "$DIR" | md5 2>/dev/null || printf '%s' "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1)
CACHE_FILE="/tmp/statusline-git-cache-${CACHE_DIR_KEY}"
CACHE_MAX_AGE=5  # seconds

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] && return 0
    local age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    [ "$age" -gt "$CACHE_MAX_AGE" ]
}

if cache_is_stale; then
    if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH_NAME=$(git -C "$DIR" branch --show-current 2>/dev/null)
        STAGED=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        printf '1|%s|%s|%s\n' "$BRANCH_NAME" "$STAGED" "$MODIFIED" > "$CACHE_FILE"
    else
        printf '0|||\n' > "$CACHE_FILE"
    fi
fi

IFS='|' read -r IS_GIT BRANCH_NAME STAGED MODIFIED < "$CACHE_FILE"

# Folder name — show current_dir in brackets if different from project_dir
FOLDER=$(basename "$DIR")
if [ -n "$CUR_DIR" ] && [ "$CUR_DIR" != "$DIR" ]; then
    FOLDER="${FOLDER} ($(basename "$CUR_DIR"))"
fi

# Context — input(total)/cache(subset)/output/remaining
CACHE_TOKENS=$((CUR_CACHE_READ + CUR_CACHE_CREATE))
INPUT_K=$(( (TOTAL_INPUT + CACHE_TOKENS) / 1000 ))
CACHE_K=$((CACHE_TOKENS / 1000))
OUTPUT_K=$((TOTAL_OUTPUT / 1000))
CTX_TEXT="${INPUT_K}K in / ${CACHE_K}K cached / ${OUTPUT_K}K out / ${REMAINING_PCT}% remaining"

# Context bar — heavy for filled, light for empty
FILLED=$((PCT * 10 / 100))
EMPTY=$((10 - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR="${FG_BASE}$(printf "%${FILLED}s" | tr ' ' '━')"
[ "$EMPTY"  -gt 0 ] && BAR="${BAR}${FG_DIM}$(printf "%${EMPTY}s" | tr ' ' '─')"
BAR="${BAR}${FG_BASE}"

# Cost and duration formatting
COST_FMT=$(awk -v c="$COST" 'BEGIN { printf "$%.3f\n", c+0 }')

# Daily cost tracking (persists across sessions)
cost_file="$HOME/.claude/daily-cost.json"
today=$(date +%Y-%m-%d)
if [ -f "$cost_file" ]; then
  stored_date=$(jq -r '.date // ""' "$cost_file" 2>/dev/null)
  if [ "$stored_date" != "$today" ]; then
    echo "{\"date\":\"$today\",\"sessions\":{}}" > "$cost_file"
  fi
else
  echo "{\"date\":\"$today\",\"sessions\":{}}" > "$cost_file"
fi
jq --arg sid "$SESSION_ID" --argjson c "${COST:-0}" '.sessions[$sid] = $c' "$cost_file" > "${cost_file}.tmp" && mv "${cost_file}.tmp" "$cost_file"
daily_cost=$(jq '[.sessions[]] | add // 0' "$cost_file")
DAILY_FMT=$(awk -v c="$daily_cost" 'BEGIN { printf "$%.2f\n", c+0 }')
DURATION_FMT=$(awk -v ms="$DURATION_MS" 'BEGIN {
    s = int(ms / 1000); m = int(s / 60); h = int(m / 60)
    if (h > 0) printf "%dh%dm", h, m % 60
    else        printf "%dm", m
}')

# Determine git bg/fg colors based on dirty state
GIT_BG="$BG_GREEN"; GIT_FG="$FG_GREEN"
if [ "${IS_GIT:-0}" = "1" ]; then
    GIT_DIRTY=0
    [ "${STAGED:-0}" -gt 0 ] || [ "${MODIFIED:-0}" -gt 0 ] && GIT_DIRTY=1
    [ "$GIT_DIRTY" = "1" ] && GIT_BG="$BG_YELLOW" && GIT_FG="$FG_YELLOW"
fi

# Determine vim bg/fg colors
VIM_BG="$BG_GREEN"; VIM_FG="$FG_GREEN"
[ "$VIM_MODE" = "NORMAL" ] && VIM_BG="$BG_YELLOW" && VIM_FG="$FG_YELLOW"

# Build line — LAST_FG tracks the previous segment's bg color for the right cap
LINE="${RESET}${FG_TEAL}${CAP_L}${BG_TEAL}${FG_BASE}${BOLD} ${FOLDER} "
LAST_FG="$FG_TEAL"

# Model segment
LINE="${LINE}${LAST_FG}${BG_BLUE}${SEP}${FG_BASE}${BOLD} ${CHIP} ${MODEL} "
LAST_FG="$FG_BLUE"

if [ "${IS_GIT:-0}" = "1" ]; then
    GIT_TEXT="${BRANCH} ${BRANCH_NAME}"
    [ "${STAGED:-0}"   -gt 0 ] && GIT_TEXT="${GIT_TEXT} +${STAGED}"
    [ "${MODIFIED:-0}" -gt 0 ] && GIT_TEXT="${GIT_TEXT} ~${MODIFIED}"
    LINE="${LINE}${LAST_FG}${GIT_BG}${SEP}${FG_BASE}${BOLD} ${GIT_TEXT} "
    LAST_FG="$GIT_FG"
fi

# Context segment
LINE="${LINE}${LAST_FG}${BG_MAUVE}${SEP}${FG_BASE}${BOLD} ${BAR} ${CTX_TEXT} "
LAST_FG="$FG_MAUVE"

# Cost segment
LINE="${LINE}${LAST_FG}${BG_PEACH}${SEP}${FG_BASE}${BOLD} ${COST_FMT} (today: ${DAILY_FMT}) "
LAST_FG="$FG_PEACH"

# Output style — teal pill, hidden when default
if [ -n "$STYLE" ] && [ "$STYLE" != "default" ]; then
    LINE="${LINE}${LAST_FG}${BG_TEAL}${SEP}${FG_BASE}${BOLD} ${STYLE} "
    LAST_FG="$FG_TEAL"
fi

# Agent — peach pill, only shown when --agent flag is active
if [ -n "$AGENT" ]; then
    LINE="${LINE}${LAST_FG}${BG_PEACH}${SEP}${FG_BASE}${BOLD} ${ROBOT} ${AGENT} "
    LAST_FG="$FG_PEACH"
fi

# Vim mode — only shown when vim mode is enabled
if [ -n "$VIM_MODE" ]; then
    LINE="${LINE}${LAST_FG}${VIM_BG}${SEP}${FG_BASE}${BOLD} ${VIM_MODE} "
    LAST_FG="$VIM_FG"
fi

# Right rounded cap
LINE="${LINE}${RESET}${LAST_FG}${CAP_R}${RESET}"

printf '%b\n' "$LINE"