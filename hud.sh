#!/usr/bin/env bash
# Minimal Claude Code statusline: model + dir + git on line 1, ctx/5h/7d bars on line 2.
# Optional config: ~/.claude/claude-mini-hud.json (see README for schema).
set -euo pipefail

input=$(cat)

# ---------- config ----------
CONFIG_PATH="${CLAUDE_MINI_HUD_CONFIG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/claude-mini-hud.json}"
config='{}'
if [ -f "$CONFIG_PATH" ]; then
  if parsed=$(jq -c . "$CONFIG_PATH" 2>/dev/null); then
    config=$parsed
  fi
fi

cfg() { printf '%s' "$config" | jq -r "$1 // empty"; }

th_warn=$(cfg '.thresholds.warn');     th_warn=${th_warn:-50}
th_alert=$(cfg '.thresholds.alert');   th_alert=${th_alert:-75}
th_crit=$(cfg '.thresholds.critical'); th_crit=${th_crit:-90}

bar_width=$(cfg '.barWidth');          bar_width=${bar_width:-10}
show_git=$(cfg '.showGit');            show_git=${show_git:-true}
bar_filled_char=$(cfg '.bar.filled');  bar_filled_char=${bar_filled_char:-█}
bar_empty_char=$(cfg '.bar.empty');    bar_empty_char=${bar_empty_char:-░}
separator_char=$(cfg '.separator');    separator_char=${separator_char:-│}

# ---------- color parsing ----------
RESET=$'\e[0m'

# Translate a color value ("cyan", 36, "#FF6600", "256:208", "dim", "") into an ANSI escape.
# Empty input yields empty string (caller decides fallback).
color_code() {
  local v=${1:-}
  [ -z "$v" ] && return
  case "$v" in
    dim)       printf '\e[2m' ;;
    bold)      printf '\e[1m' ;;
    black)     printf '\e[30m' ;;
    red)       printf '\e[31m' ;;
    green)     printf '\e[32m' ;;
    yellow)    printf '\e[33m' ;;
    blue)      printf '\e[34m' ;;
    magenta)   printf '\e[35m' ;;
    cyan)      printf '\e[36m' ;;
    white)     printf '\e[37m' ;;
    gray|grey) printf '\e[90m' ;;
    256:*)     printf '\e[38;5;%sm' "${v#256:}" ;;
    \#*)
      local hex=${v#\#}
      if [ ${#hex} -eq 6 ]; then
        local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
        printf '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
      fi
      ;;
    [0-9]*)    printf '\e[%sm' "$v" ;;
    *)         ;;
  esac
}

resolve_color() { # $1=config-path $2=fallback-name
  local v; v=$(cfg "$1")
  [ -z "$v" ] && v=$2
  color_code "$v"
}

DIM=$(resolve_color '.colors.dim' 'dim')
C_LOW=$(resolve_color '.colors.low' 'cyan')
C_WARN=$(resolve_color '.colors.warn' 'yellow')
C_ALERT=$(resolve_color '.colors.alert' 'magenta')
C_CRIT=$(resolve_color '.colors.critical' 'red')
C_MODEL=$(resolve_color '.colors.model' 'cyan')
C_PROJECT=$(resolve_color '.colors.project' 'yellow')
C_BRANCH=$(resolve_color '.colors.branch' 'cyan')

# ---------- stdin extraction ----------
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
color_for_pct() {
  local p=${1%.*}
  if [ -z "$p" ]; then printf '%s' "$DIM"; return; fi
  if   [ "$p" -ge "$th_crit"  ]; then printf '%s' "$C_CRIT"
  elif [ "$p" -ge "$th_alert" ]; then printf '%s' "$C_ALERT"
  elif [ "$p" -ge "$th_warn"  ]; then printf '%s' "$C_WARN"
  else                                printf '%s' "$C_LOW"
  fi
}

bar() {
  local pct=${1:-} width=${2:-$bar_width}
  if [ -z "$pct" ]; then printf '%*s' "$width" '' | tr ' ' "$bar_empty_char"; return; fi
  local p=${pct%.*}
  [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  local filled=$(( (p * width + 50) / 100 ))
  local empty=$(( width - filled ))
  local out=''
  [ "$filled" -gt 0 ] && out+=$(printf '%*s' "$filled" '' | tr ' ' "$bar_filled_char")
  [ "$empty"  -gt 0 ] && out+=$(printf '%*s' "$empty"  '' | tr ' ' "$bar_empty_char")
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
if [ "$show_git" = "true" ] && [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo '')
  dirty=''
  if ! git -C "$cwd" diff --quiet --ignore-submodules HEAD 2>/dev/null; then dirty='*'; fi
  if [ -n "$branch" ]; then
    git_part=" ${DIM}git:(${RESET}${C_BRANCH}${branch}${dirty}${RESET}${DIM})${RESET}"
  fi
fi

printf '%s[%s%s%s]%s %s%s%s%s\n' \
  "$DIM" "$RESET$C_MODEL" "$model" "$RESET$DIM" "$RESET" \
  "$C_PROJECT" "$dir_label" "$RESET" "$git_part"

# ---------- line 2: ctx | 5h | 7d ----------
ctx_color=$(color_for_pct "${ctx_pct:-}")
five_color=$(color_for_pct "${five_pct:-}")
seven_color=$(color_for_pct "${seven_pct:-}")

ctx_seg="${DIM}ctx${RESET} ${ctx_color}$(bar "${ctx_pct:-}") $(fmt_pct "${ctx_pct:-}")${RESET}"

five_reset_str=$(fmt_reset "${five_reset:-}")
five_seg="${DIM}5h${RESET} ${five_color}$(bar "${five_pct:-}") $(fmt_pct "${five_pct:-}")${RESET}"
[ -n "$five_reset_str" ] && five_seg+=" ${DIM}(${five_reset_str})${RESET}"

seven_reset_str=$(fmt_reset "${seven_reset:-}")
seven_seg="${DIM}7d${RESET} ${seven_color}$(bar "${seven_pct:-}") $(fmt_pct "${seven_pct:-}")${RESET}"
[ -n "$seven_reset_str" ] && seven_seg+=" ${DIM}(${seven_reset_str})${RESET}"

sep=" ${DIM}${separator_char}${RESET} "
printf '%s%s%s%s%s\n' "$ctx_seg" "$sep" "$five_seg" "$sep" "$seven_seg"
