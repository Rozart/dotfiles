function refresh_ssh_agent --description 'Refresh the SSH agent for Rex or tmux'
    if set -q REX_SESSION
        set -gx SSH_AUTH_SOCK "$HOME/.local/state/rex/ssh-agent/unrouted.sock"
        if set -q REX_BLOCK; and string match -rq '^block:[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' -- $REX_BLOCK
            set -l block_id (string replace 'block:' '' -- $REX_BLOCK)
            set -gx SSH_AUTH_SOCK "$HOME/.local/state/rex/ssh-agent/b-$block_id.sock"
        end
    else if set -q TMUX
        set -l stable_socket $HOME/.ssh/ssh_auth_sock
        if test -S $stable_socket
            set -gx SSH_AUTH_SOCK $stable_socket
        end
    end
end
