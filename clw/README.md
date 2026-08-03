# clw

Fish function that schedules a one-shot Claude Code run at a specific time in the current directory, using `systemd-run --user` (no cron/`at` package required). Runs `claude --dangerously-skip-permissions -p "..."` unattended, so it needs no TTY to approve prompts.

---

## Usage

```fish
clw -a "14:45" -p "audit this repo and fix what you find"   # schedule directly
clw --at "14:45"                                             # partial -- prompts for the missing prompt
clw                                                           # no flags -- prompts for both
clw --jobs                                                    # fuzzy-list pending jobs; Enter cancels, Esc just browses
clw --help                                                    # usage only
```

A bare `HH:MM` is treated as *today* and pinned to today's date so it fires once, not daily. Pass a full `YYYY-MM-DD HH:MM` for a future date.

Each scheduled job gets a unique unit name (`claude-<dirname>-<timestamp>`), so multiple jobs can be queued without colliding. Watch a job's output with `journalctl --user -u <unit> -f`.

---

## Install

```bash
chmod +x apply_clw_setup.sh
./apply_clw_setup.sh
```

Symlinks `clw.fish` into `~/.config/fish/functions/clw.fish` (fish's autoload convention — lazy-loaded, not parsed on every shell startup). Editing `clw.fish` in this repo takes effect immediately, no reinstall needed.

## Revert

```bash
chmod +x revert_clw_setup.sh
./revert_clw_setup.sh
```

---

## Notes

- `--dangerously-skip-permissions` means Claude Code won't ask for confirmation on anything since there's no terminal attached to approve prompts. Review `git diff` in the target project after a run.
- Requires `fzf` for `clw --jobs`.
