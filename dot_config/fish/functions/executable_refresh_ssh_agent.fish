function refresh_ssh_agent --description 'Refresh the SSH agent for Rex or tmux'
    if set -q REX_SESSION
        set -gx SSH_AUTH_SOCK "$HOME/.local/state/rex/ssh-agent/unrouted.sock"
        if set -q REX_BLOCK; and string match -rq '^block:[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' -- $REX_BLOCK
            set -l block_id (string replace 'block:' '' -- $REX_BLOCK)
            set -gx SSH_AUTH_SOCK "$HOME/.local/state/rex/ssh-agent/b-$block_id.sock"
        end
    else if set -q TMUX
        set -l live_socket (tmux show-env SSH_AUTH_SOCK 2>/dev/null | cut -d'=' -f2)
        if test -n "$live_socket"
            set -gx SSH_AUTH_SOCK $live_socket
        end
    end
end
