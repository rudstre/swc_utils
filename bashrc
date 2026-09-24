# Start a 7-day interactive allocation
alias srun-cpu7d='srun --nodes=1 --ntasks-per-node=1 --cpus-per-task=8 --time=7-00:00:00 --mem=32G --pty bash -i'

# Jump back into an existing allocation
jump-in() {
    srun --jobid="$1" --overlap --pty bash -i
}


# Return the Slurm step ID(s) belonging to our VS Code tunnel
_ct_steps() {
    [[ -n "$SLURM_JOB_ID" ]] || return 0

    squeue -h -s -j"$SLURM_JOB_ID" -o "%i|%j" 2>/dev/null \
        | awk -F'|' '$2 == "vscode-tunnel" { print $1 }'
}


# Start VS Code tunnel as its own Slurm step
ct() {
    if [[ -z "$SLURM_JOB_ID" ]]; then
        echo "Not inside a Slurm allocation."
        echo "Run srun-cpu7d first."
        return 1
    fi

    local existing
    existing="$(_ct_steps)"

    if [[ -n "$existing" ]]; then
        echo "VS Code tunnel step already exists:"
        echo "$existing"
        return 1
    fi

    # Machine-local runtime/server state.
    # Because your allocation is one node, these remain valid for the life
    # of this allocation but are NOT shared with other cluster nodes.
    local runtime_dir="/tmp/vscode-runtime-$USER-$SLURM_JOB_ID"
    local server_dir="/tmp/vscode-server-$USER-$SLURM_JOB_ID"
    local ext_dir="$HOME/.vscode-server/extensions"
    mkdir -p "$runtime_dir" "$server_dir"
    chmod 700 "$runtime_dir"

    echo "Starting VS Code as a Slurm step in job $SLURM_JOB_ID..."

    nohup srun \
        --jobid="$SLURM_JOB_ID" \
        --overlap \
        --nodes=1 \
        --ntasks=1 \
        --job-name=vscode-tunnel \
        bash -lc "
            export XDG_RUNTIME_DIR='$runtime_dir'

            exec '$HOME/.local/bin/micromamba' run \
                -n GridMaze_mFC_ephys \
                '$HOME/.local/bin/code' \
                    tunnel \
                    --server-data-dir '$server_dir' \
                    --extensions-dir '$ext_dir' \
                    --verbose
        " \
        >>"$HOME/code-tunnel.log" 2>&1 </dev/null &

    disown

    # Give Slurm a moment to register the step
    sleep 2

    local step
    step="$(_ct_steps)"

    if [[ -n "$step" ]]; then
        echo "VS Code tunnel started."
        echo "Slurm step: $step"
        echo "Log: ~/code-tunnel.log"
    else
        echo "Tunnel command submitted, but no vscode-tunnel step is visible yet."
        echo "Check: tail -100 ~/code-tunnel.log"
    fi
}


# Stop VS Code by cancelling its Slurm step.
# Usage:
#   kct          -> stop
#   kct restart  -> stop, then start again
kct() {
    if [[ -z "$SLURM_JOB_ID" ]]; then
        echo "Not inside a Slurm allocation."
        return 1
    fi

    local steps
    steps="$(_ct_steps)"

    if [[ -z "$steps" ]]; then
        echo "No VS Code tunnel step running."
    else
        echo "Stopping VS Code Slurm step(s):"
        echo "$steps"

        while read -r step; do
            [[ -n "$step" ]] && scancel "$step"
        done <<< "$steps"

        # Wait until Slurm confirms the step is gone.
        for _ in {1..20}; do
            [[ -z "$(_ct_steps)" ]] && break
            sleep 0.5
        done

        if [[ -n "$(_ct_steps)" ]]; then
            echo "Warning: VS Code step is still terminating."
        else
            echo "VS Code step stopped."
        fi
    fi

    if [[ "$1" == "restart" ]]; then
        ct
    fi
}


ctstatus() {
    if [[ -z "$SLURM_JOB_ID" ]]; then
        echo "Not inside a Slurm allocation."
        return 1
    fi

    echo "Allocation: $SLURM_JOB_ID"
    echo
    squeue -s -j"$SLURM_JOB_ID" -o "%.18i %.24j %.12M %N"

    echo
    echo "VS Code processes:"
    ps -u "$USER" -o pid,ppid,pgid,sid,nlwp,cmd \
        | grep -E 'code.*tunnel|vscode/cli/servers|vscode-server|codex.*app-server' \
        | grep -v grep \
        || echo "None"
}

# !! Contents within this block are managed by 'micromamba shell init' !!
export MAMBA_EXE='/nfs/nhome/live/rudyg/.local/bin/micromamba';
export MAMBA_ROOT_PREFIX='/nfs/nhome/live/rudyg/micromamba';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from micromamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<

# >>> Codex installer >>>
export PATH="/nfs/nhome/live/rudyg/.local/bin:$PATH"
# <<< Codex installer <<<

export PATH="$HOME/bin:$PATH"