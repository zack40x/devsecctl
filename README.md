# devsecctl

A macOS-friendly Dev + Security control center (CLI).

**Why it exists:** when Docker/ports are acting up or you need a quick macOS incident-style snapshot, you shouldn’t be hunting for 15 different commands.

## Features

### Ports
- List listening ports + owning processes
- Identify who owns a port
- Kill the process holding a port

### Docker / Compose
- Check Docker engine status
- List running containers
- `up/down` a compose stack (auto-detects compose file)
- Safe cleanup (`system prune`)

### Security Snapshot (macOS)
Creates a timestamped bundle under `output/snapshots/<timestamp>/`:
- system info
- running processes
- listening ports + established connections
- logged-in users + recent logins
- persistence checks (LaunchAgents/Daemons, cron)
- `report.md` summary

### Redaction for Safe Sharing
Creates a sanitized copy under `output/redacted/<timestamp>/`:
- removes usernames + `/Users/<name>` paths
- masks private IPs + MAC addresses (best-effort)

## Install

### Clone + run locally
```bash
git clone https://github.com/zack40x/devsecctl.git
cd devsecctl
chmod +x devsecctl
./devsecctl help

## Zsh tab completion (macOS/Linux)

devsecctl ships a zsh completion script. During install, it is copied to:

- `~/.zsh/completions/_devsecctl`

If your shell does not already have completions enabled, add this to `~/.zshrc`:

```zsh
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit
compinit
