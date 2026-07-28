function pbcopy -d "Copy stdin to the client (Mac) clipboard"
    # Primary: ssh-forwarded pbcopy tunnel (deterministic, no size limits).
    # Fallback: OSC 52 — tmux (set-clipboard on) forwards it to the outer
    # terminal, so it works inside tmux, nested tmux, and bare ssh.
    set -l data (cat | string collect --no-trim-newlines)
    if not printf '%s' $data | nc -N -w 1 127.0.0.1 2490 2>/dev/null
        printf '\e]52;c;%s\a' (printf '%s' $data | base64 -w 0) >/dev/tty
    end
end
