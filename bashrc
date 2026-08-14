export PATH="$HOME/bin:$PATH"
alias ct='setsid -f "$HOME/.local/bin/code" tunnel --verbose </dev/null >~/code-tunnel.log 2>&1'

smem() {
    local total
    total=$(scontrol show job "$SLURM_JOB_ID" | grep -oE 'MinMemoryNode=[^ ]+' | cut -d= -f2 | sed 's/G//')
    sstat -j "$SLURM_JOB_ID" --format=MaxRSS --noheader | awk -v total="$total" '{printf "%.2fGB / %.2fGB\n", $1/1024/1024, total}'
}

rctf() {
    echo "=== Force resetting VS Code tunnel ==="

    echo "[1/7] Killing tunnel..."
    pkill -u "$USER" -f "code tunnel" || true

    echo "[2/7] Killing VS Code agent hosts..."
    pkill -u "$USER" -f "$HOME/.vscode/cli" || true

    echo "[3/7] Killing VS Code servers..."
    pkill -u "$USER" -f "$HOME/.vscode/cli/servers" || true

    echo "[4/7] Killing extension and terminal hosts..."
    pkill -u "$USER" -f "extensionHost" || true
    pkill -u "$USER" -f "ptyHost" || true

    echo "[5/7] Removing stale sockets..."
    rm -f /tmp/code-* 2>/dev/null || true

    echo "[6/7] Waiting..."
    sleep 3

    echo "Remaining VS Code processes:"
    ps -u "$USER" -f | grep -E "code|server-main|extensionHost|ptyHost|agent-host" | grep -v grep || echo "None"

    echo "[7/7] Starting fresh tunnel..."
    setsid -f "$HOME/.local/bin/code" tunnel --verbose </dev/null >~/code-tunnel.log 2>&1
}
# >>> mamba initialize >>>
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
