# Nightly Code Review

Automated nightly reviews run Claude Code in read-only mode against every package in the QPS ecosystem. The goal is to catch safety issues, inconsistencies, and drift between packages while nobody is at the keyboard.

## Ecosystem Coverage

| Package | Review Focus |
|---------|-------------|
| QPSDrive.jl | Instrument safety, scan engine, WebSocket server, mock consistency |
| SolInstrumentsMS.jl | Serial protocol correctness, resource cleanup, concurrency |
| QPSTools.jl | Numerical correctness, type stability, API consistency |
| SpectroscopyTools.jl | Type hierarchy, interface contracts, downstream breaking changes |
| QPSView.jl | File monitoring, Makie lifecycle, error handling |

Each project gets a tailored prompt that targets the most important concerns for that codebase. Reviews are strictly read-only — no files are modified.

## How It Works

A shell script at `~/.qpsdrive/nightly-review.sh` loops over the five projects and runs:

```bash
claude -p "<review prompt>" \
    --allowedTools 'Read,Grep,Glob,Task' \
    --output-format text \
    -d /path/to/project \
    > ~/.qpsdrive/reviews/ProjectName_2026-02-17_0200.log
```

Key flags:

| Flag | Purpose |
|------|---------|
| `-p` | Print mode — non-interactive, exits when done |
| `--allowedTools` | Restricts to read-only tools (no edits, no bash) |
| `--output-format text` | Plain text output for log files |
| `-d` | Sets the working directory to the project root |

A macOS `launchd` agent triggers the script at 2:00 AM daily. Logs are written to `~/.qpsdrive/reviews/` with timestamps.

## File Locations

| File | Path |
|------|------|
| Review script | `~/.qpsdrive/nightly-review.sh` |
| Launch agent | `~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist` |
| Review logs | `~/.qpsdrive/reviews/<Package>_<timestamp>.log` |

## Setup

### 1. Load the launch agent

```bash
launchctl load ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist
```

### 2. Verify it's registered

```bash
launchctl list | grep qpsdrive
```

You should see a line with `com.qpsdrive.nightly-review`.

### 3. Test manually

```bash
~/.qpsdrive/nightly-review.sh
```

This runs the full review immediately and prints progress to the terminal. Check `~/.qpsdrive/reviews/` for the output files.

## Reading the Logs

Each log file contains a structured review of one project. Findings include `file:line` references that can be jumped to in VS Code or any editor.

```bash
# Latest review for QPSDrive
ls -t ~/.qpsdrive/reviews/QPSDrive.jl_*.log | head -1 | xargs less

# Search all recent reviews for a keyword
grep -l "serial" ~/.qpsdrive/reviews/*_$(date +%Y-%m-%d)*.log
```

## Maintenance

### Change the schedule

Edit the plist and reload:

```bash
# Edit the Hour/Minute in the plist
vim ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist

# Reload
launchctl unload ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist
launchctl load ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist
```

### Disable temporarily

```bash
launchctl unload ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist
```

### Re-enable

```bash
launchctl load ~/Library/LaunchAgents/com.qpsdrive.nightly-review.plist
```

### Add a new project

Add the project path to the `PROJECTS` array and a matching entry to the `PROMPTS` associative array in `~/.qpsdrive/nightly-review.sh`.

## Sleep and Wake

`launchd` will not fire if the Mac is asleep at 2:00 AM. Options:

1. **Schedule a wake** — `sudo pmset repeat wakeorpoweron MTWRFSU 01:55:00`
2. **Change the time** — set `Hour` and `Minute` in the plist to a time the machine is typically awake
3. **Run manually** — just run `~/.qpsdrive/nightly-review.sh` when you arrive in the morning

If the Mac was asleep at the scheduled time, `launchd` runs the job once when it next wakes up (this is the default behavior for `StartCalendarInterval`).
