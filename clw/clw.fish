function clw --description "Schedule a one-shot Claude Code run via systemd-run"
    argparse 'h/help' 'a/at=' 'p/prompt=' 'jobs' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: clw -a|--at HH:MM -p|--prompt \"text\"   schedule a run in the current dir"
        echo "       clw                                       no flags -- prompts for both"
        echo "       clw --jobs                                list pending jobs (Enter cancels, Esc browses)"
        return
    end

    if set -q _flag_jobs
        set -l unit (systemctl --user list-timers --no-legend 'claude-*' | grep -oE 'claude-\S+\.timer' | fzf --preview 'systemctl --user status {}')
        if test -n "$unit"
            systemctl --user stop $unit
            echo "Cancelled $unit"
        end
        return
    end

    set -l when $_flag_at
    set -l prompt $_flag_prompt

    if test -z "$when"; and test -z "$prompt"
        echo "Usage: clw -a HH:MM -p \"prompt text\"  (answer the prompts below, or run 'clw --help')"
    end
    if test -z "$when"
        read -P "Run at (HH:MM, today unless a date is given): " when
    end
    if test -z "$prompt"
        read -P "Prompt: " prompt
    end

    # Bare HH:MM means "today" -- prefix today's date so it fires once, not daily
    if string match -qr '^\d{1,2}:\d{1,2}(:\d{1,2})?$' -- "$when"
        set when (date +%Y-%m-%d)" $when"
    end

    set -l dir (pwd)
    set -l unit "claude-"(path basename $dir)"-"(date +%s)

    if systemd-run --user \
        --unit=$unit \
        --on-calendar="$when" \
        --working-directory="$dir" \
        -- claude --dangerously-skip-permissions -p "$prompt"
        echo "Scheduled '$unit.timer' for $when in $dir"
        echo "Watch:  journalctl --user -u $unit -f"
        echo "Cancel: clw --jobs"
    end
end
