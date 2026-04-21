# claude-mini-hud

A minimal two-line statusline for [Claude Code](https://claude.com/claude-code) that shows model, directory, git branch, and — the part the native HUD is missing — **context / 5-hour / 7-day usage bars** at a glance.

## Preview

```
[Opus 4.7] my-project git:(main*)
ctx ░░░░░░░░░░ 4% │ 5h ███░░░░░░░ 25% (3h54m) │ 7d ███░░░░░░░ 33% (5d13h)
```

Bar color shifts as usage rises: cyan (<50%) → yellow (50–74%) → magenta (75–89%) → red (≥90%).
Reset time format adapts to what's left: `45m`, `3h54m`, `5d13h`.

## Why

The native Claude Code statusline doesn't surface rate-limit usage. The existing [`claude-hud`](https://github.com/jarrodwatts/claude-hud) plugin is feature-rich but can get verbose. This script is the opposite end: just two lines, three bars, no config.

## Requirements

- `bash`
- `jq`
- `git` (optional — only used for the branch indicator)

## Install

1. Put `hud.sh` somewhere on your machine, e.g. `~/.claude/hud.sh`:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Stefansong/claude-mini-hud/main/hud.sh -o ~/.claude/hud.sh
   chmod +x ~/.claude/hud.sh
   ```

2. Add this to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash /Users/YOU/.claude/hud.sh"
     }
   }
   ```

3. Restart Claude Code.

## Data source

All values come from the JSON that Claude Code pipes to `stdin` of your statusline script — no extra API calls:

- `model.display_name`
- `workspace.current_dir`
- `context_window.used_percentage` (Claude Code v2.1.6+; falls back to token ratio)
- `rate_limits.five_hour.{used_percentage, resets_at}`
- `rate_limits.seven_day.{used_percentage, resets_at}`

## License

MIT — see [LICENSE](LICENSE).
