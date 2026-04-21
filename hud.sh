#!/usr/bin/env bash
# Minimal Claude Code statusline: model + dir + git on line 1, ctx/5h/7d bars on line 2.
set -euo pipefail

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "Claude"')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')

ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$ctx_pct" ]; then
  ctx_pct=$(printf '%s' "$input" | jq -r '
    (.context_window.current_usage // {}) as $u
    | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)) as $used
    | (.context_window.context_window_size // 200000) as $total
    | if $total > 0 then (($used / $total) * 100) else empty end
  ')
fi

five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ---------- formatting helpers ----------
DIM=$'\e[2m'; RESET=$'\e[0m'
CYAN=$'\e[36m'; YELLOW=$'\e[33m'; MAGENTA=$'\e[35m'; RED=$'\e[31m'; GREEN=$'\e[32m'

color_for_pct() {
  local p=${1%.*}
  if [ -z "$p" ]; then printf '%s' "$DIM"; return; fi
  if [ "$p" -ge 90 ]; then printf '%s' "$RED";
  elif [ "$p" -ge 75 ]; then printf '%s' "$MAGENTA";
  elif [ "$p" -ge 50 ]; then printf '%s' "$YELLOW";
  else printf '%s' "$CYAN"; fi
}

bar() {
  local pct=${1:-} width=${2:-10}
  if [ -z "$pct" ]; then printf '%*s' "$width" '' | tr ' ' '░'; return; fi
  local p=${pct%.*}
  [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  local filled=$(( (p * width + 50) / 100 ))
  local empty=$(( width - filled ))
  local out=''
  [ "$filled" -gt 0 ] && out+=$(printf '%*s' "$filled" '' | tr ' ' '█')
  [ "$empty"  -gt 0 ] && out+=$(printf '%*s' "$empty"  '' | tr ' ' '░')
  printf '%s' "$out"
}

fmt_pct() {
  [ -z "${1:-}" ] && { printf '--'; return; }
  printf '%d%%' "${1%.*}"
}

fmt_reset() {
  local ts=${1:-}
  [ -z "$ts" ] && return
  local now diff
  now=$(date +%s)
  diff=$(( ts - now ))
  [ "$diff" -le 0 ] && return
  local d=$((diff/86400)); local h=$(( (diff%86400)/3600 )); local m=$(( (diff%3600)/60 ))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

# ---------- line 1: model + dir + git ----------
dir_label=$(basename "$cwd" 2>/dev/null || echo "")
git_part=''
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo '')
  dirty=''
  if ! git -C "$cwd" diff --quiet --ignore-submodules HEAD 2>/dev/null; then dirty='*'; fi
  if [ -n "$branch" ]; then
    git_part=" ${DIM}git:(${RESET}${CYAN}${branch}${dirty}${RESET}${DIM})${RESET}"
  fi
fi

printf '%s[%s%s%s]%s %s%s%s%s\n' \
  "$DIM" "$RESET$CYAN" "$model" "$RESET$DIM" "$RESET" \
  "$YELLOW" "$dir_label" "$RESET" "$git_part"

# ---------- line 2: ctx | 5h | 7d ----------
ctx_color=$(color_for_pct "${ctx_pct:-}")
five_color=$(color_for_pct "${five_pct:-}")
seven_color=$(color_for_pct "${seven_pct:-}")

ctx_seg="${DIM}ctx${RESET} ${ctx_color}$(bar "${ctx_pct:-}" 10) $(fmt_pct "${ctx_pct:-}")${RESET}"

five_reset_str=$(fmt_reset "${five_reset:-}")
five_seg="${DIM}5h${RESET} ${five_color}$(bar "${five_pct:-}" 10) $(fmt_pct "${five_pct:-}")${RESET}"
[ -n "$five_reset_str" ] && five_seg+=" ${DIM}(${five_reset_str})${RESET}"

seven_reset_str=$(fmt_reset "${seven_reset:-}")
seven_seg="${DIM}7d${RESET} ${seven_color}$(bar "${seven_pct:-}" 10) $(fmt_pct "${seven_pct:-}")${RESET}"
[ -n "$seven_reset_str" ] && seven_seg+=" ${DIM}(${seven_reset_str})${RESET}"

sep=" ${DIM}│${RESET} "
printf '%s%s%s%s%s\n' "$ctx_seg" "$sep" "$five_seg" "$sep" "$seven_seg"
