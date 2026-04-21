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

### Option A: Claude Code plugin (recommended)

Inside Claude Code:

```
/plugin marketplace add Stefansong/claude-mini-hud
/plugin install claude-mini-hud
/claude-mini-hud:setup
```

Then restart Claude Code.

### Option B: Manual

1. Download `hud.sh`:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Stefansong/claude-mini-hud/main/hud.sh -o ~/.claude/hud.sh
   chmod +x ~/.claude/hud.sh
   ```

2. Add to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/hud.sh"
     }
   }
   ```

3. Restart Claude Code.

## Customize

Drop a JSON file at `~/.claude/claude-mini-hud.json` (or point `CLAUDE_MINI_HUD_CONFIG` at any path). All keys are optional — missing keys fall back to defaults shown here:

```json
{
  "thresholds": { "warn": 50, "alert": 75, "critical": 90 },
  "colors": {
    "low": "cyan",
    "warn": "yellow",
    "alert": "magenta",
    "critical": "red",
    "model": "cyan",
    "project": "yellow",
    "branch": "cyan",
    "dim": "dim"
  },
  "barWidth": 10,
  "bar": { "filled": "█", "empty": "░" },
  "separator": "│",
  "showGit": true
}
```

### Color values

Any field under `colors.*` accepts:

| Form | Example | Notes |
|------|---------|-------|
| Name | `"cyan"` | `black red green yellow blue magenta cyan white gray dim bold` |
| ANSI code | `"36"` or `"1;33"` | Raw SGR parameters |
| 256-color | `"256:208"` | Orange; any index 0–255 |
| 24-bit hex | `"#FF6600"` | Full RGB — needs a true-color terminal |

### Thresholds

`warn`, `alert`, `critical` are integer percentages. A bar uses `colors.critical` when usage ≥ `critical`, else `alert` when ≥ `alert`, else `warn` when ≥ `warn`, else `low`.

A sample config is in [`config.example.json`](config.example.json).

## Data source

All values come from the JSON that Claude Code pipes to `stdin` of your statusline script — no extra API calls:

- `model.display_name`
- `workspace.current_dir`
- `context_window.used_percentage` (Claude Code v2.1.6+; falls back to token ratio)
- `rate_limits.five_hour.{used_percentage, resets_at}`
- `rate_limits.seven_day.{used_percentage, resets_at}`

## License

MIT — see [LICENSE](LICENSE).
