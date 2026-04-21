---
description: Configure claude-mini-hud as your statusline
allowed-tools: Bash, Read, Edit
---

Write a `statusLine` entry into the user's `settings.json` that dynamically resolves the latest installed version of `claude-mini-hud` and runs its `hud.sh`.

## Step 1: Verify plugin is installed

```bash
ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/claude-mini-hud/claude-mini-hud/*/ 2>/dev/null | awk -F/ '{ print $(NF-1) "\t" $(0) }' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-
```

If the output is empty, tell the user to run `/plugin install claude-mini-hud` first and stop.

## Step 2: Verify `jq` is available

```bash
command -v jq
```

If not found, instruct the user to install it:
- macOS: `brew install jq`
- Debian/Ubuntu: `sudo apt install jq`
- Windows (Git Bash): `winget install jqlang.jq` or `choco install jq`

## Step 3: Test the script directly

Before writing config, run a smoke test so the user sees actual output:

```bash
plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/claude-mini-hud/claude-mini-hud/*/ 2>/dev/null | awk -F/ '{ print $(NF-1) "\t" $(0) }' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":30}}}' | bash "${plugin_dir}hud.sh"
```

You should see two lines of HUD output. If it errors, stop and debug.

## Step 4: Merge into `settings.json`

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` (create it as `{}` if missing) and merge in:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c 'plugin_dir=$(ls -d \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/claude-mini-hud/claude-mini-hud/*/ 2>/dev/null | awk -F/ '\"'\"'{ print $(NF-1) \"\\t\" $(0) }'\"'\"' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec bash \"${plugin_dir}hud.sh\"'"
  }
}
```

Use a real JSON serializer (`jq`, Node, Python) — don't concatenate strings. Preserve all other keys.

## Step 5: Tell the user to restart Claude Code

> Config written. **Quit Claude Code and restart** for the statusline to take effect.

The generated command resolves the plugin path at each invocation, so you don't need to re-run setup after plugin updates.
